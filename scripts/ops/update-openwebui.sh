#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-openwebui.sh"

DEFAULT_HEALTH_TIMEOUT=180
DEFAULT_WEBUI_PORT=3000
STOPPED_FOR_BACKUP=false
REDEPLOY_ATTEMPTED=false

usage() {
	cat <<'EOF'
Usage: ./scripts/ops/update-openwebui.sh [options]

Updates the local Docker Compose stack for this fork.
This script is for runtime/deployment updates, not for syncing git branches with upstream.

Options:
  --gpu                 Include docker-compose.gpu.yaml
  --compose-file FILE   Include an extra compose file (repeatable)
  --skip-backup         Skip the pre-update data backup
  --backup-dir DIR      Backup destination directory
  --skip-pull           Skip docker compose pull
  --no-build            Skip docker compose up --build
  --health-timeout SEC  Seconds to wait for open-webui health (default: 180)
  --no-log-tail         Skip the final open-webui log tail
  -h, --help            Show this help text
EOF
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

load_env_file() {
	if [ -f "$ENV_FILE" ]; then
		set -a
		# shellcheck disable=SC1090
		. "$ENV_FILE"
		set +a
	fi
}

resolve_path() {
	local path="$1"
	if [[ "$path" = /* ]]; then
		printf '%s\n' "$path"
	else
		printf '%s/%s\n' "$REPO_ROOT" "${path#./}"
	fi
}

have_container() {
	docker inspect open-webui >/dev/null 2>&1
}

container_health_status() {
	docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' open-webui
}

container_running() {
	[ "$(docker inspect --format '{{.State.Running}}' open-webui 2>/dev/null || printf 'false')" = "true" ]
}

wait_for_health() {
	local timeout_seconds="$1"
	local deadline=$((SECONDS + timeout_seconds))
	local status=""

	while [ "$SECONDS" -lt "$deadline" ]; do
		if have_container; then
			status="$(container_health_status)"
			case "$status" in
				healthy|running)
					echo "open-webui status: $status"
					return 0
					;;
				unhealthy|exited|dead)
					echo "open-webui status: $status" >&2
					return 1
					;;
			esac
		fi

		sleep 2
	done

	echo "Timed out waiting for open-webui health" >&2
	return 1
}

verify_http_health() {
	local port="$1"
	if ! command -v curl >/dev/null 2>&1; then
		return 0
	fi

	curl --silent --fail "http://127.0.0.1:${port}/health" >/dev/null
}

main() {
	require_command docker
	require_command bash

	local skip_backup=false
	local skip_pull=false
	local build_images=true
	local include_gpu=false
	local show_log_tail=true
	local health_timeout="$DEFAULT_HEALTH_TIMEOUT"
	local backup_dir=""
	local backup_archive=""
	local compose_files=("docker-compose.yaml")
	local extra_file=""
	local compose_cmd=()
	local compose_args=()
	local open_webui_port=""
	while [ $# -gt 0 ]; do
		case "$1" in
			--gpu)
				include_gpu=true
				shift
				;;
			--compose-file)
				extra_file="${2:-}"
				if [ -z "$extra_file" ]; then
					echo "--compose-file requires a value" >&2
					exit 1
				fi
				compose_files+=("$extra_file")
				shift 2
				;;
			--skip-backup)
				skip_backup=true
				shift
				;;
			--backup-dir)
				backup_dir="${2:-}"
				shift 2
				;;
			--skip-pull)
				skip_pull=true
				shift
				;;
			--no-build)
				build_images=false
				shift
				;;
			--health-timeout)
				health_timeout="${2:-}"
				shift 2
				;;
			--no-log-tail)
				show_log_tail=false
				shift
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				echo "Unknown option: $1" >&2
				usage >&2
				exit 1
				;;
		esac
	done

	if ! [[ "$health_timeout" =~ ^[0-9]+$ ]] || [ "$health_timeout" -lt 1 ]; then
		echo "--health-timeout must be a positive integer" >&2
		exit 1
	fi

	cd "$REPO_ROOT"
	load_env_file

	if [ "$include_gpu" = true ]; then
		compose_files+=("docker-compose.gpu.yaml")
	fi

	for extra_file in "${compose_files[@]}"; do
		if [ ! -f "$(resolve_path "$extra_file")" ]; then
			echo "Compose file not found: $extra_file" >&2
			exit 1
		fi
	done

	if command -v docker-compose >/dev/null 2>&1; then
		compose_cmd=("docker-compose")
	else
		compose_cmd=("docker" "compose")
	fi

	for extra_file in "${compose_files[@]}"; do
		compose_args+=(-f "$extra_file")
	done

	open_webui_port="${OPEN_WEBUI_PORT:-$DEFAULT_WEBUI_PORT}"

	if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
		echo "Warning: WEBUI_SECRET_KEY is empty. Sessions and encrypted secrets may break across updates." >&2
	fi

	restart_on_failure() {
		local exit_code="$?"
		if [ "$exit_code" -ne 0 ] && [ "$STOPPED_FOR_BACKUP" = true ] && [ "$REDEPLOY_ATTEMPTED" = false ]; then
			echo "Update failed before redeploy completed. Attempting to bring open-webui back up." >&2
			"${compose_cmd[@]}" "${compose_args[@]}" up -d open-webui >/dev/null 2>&1 || true
		fi
		exit "$exit_code"
	}
	trap restart_on_failure EXIT

	echo "Repo root: $REPO_ROOT"
	echo "Compose files: ${compose_files[*]}"

	if [ "$skip_backup" = false ] && have_container && container_running; then
		echo "Stopping open-webui for a cleaner backup..."
		"${compose_cmd[@]}" "${compose_args[@]}" stop open-webui
		STOPPED_FOR_BACKUP=true
	fi

	if [ "$skip_backup" = false ]; then
		echo "Creating pre-update backup..."
		if [ -n "$backup_dir" ]; then
			backup_archive="$("$BACKUP_SCRIPT" --backup-dir "$backup_dir")"
		else
			backup_archive="$("$BACKUP_SCRIPT")"
		fi
		echo "$backup_archive"
	fi

	if [ "$skip_pull" = false ]; then
		echo "Pulling latest service images..."
		"${compose_cmd[@]}" "${compose_args[@]}" pull
	fi

	echo "Recreating the stack..."
	REDEPLOY_ATTEMPTED=true
	if [ "$build_images" = true ]; then
		"${compose_cmd[@]}" "${compose_args[@]}" up -d --build --remove-orphans
	else
		"${compose_cmd[@]}" "${compose_args[@]}" up -d --remove-orphans
	fi

	echo "Waiting for open-webui to report healthy..."
	wait_for_health "$health_timeout"

	if verify_http_health "$open_webui_port"; then
		echo "HTTP health check passed on port $open_webui_port"
	else
		echo "HTTP health check failed on port $open_webui_port" >&2
		exit 1
	fi

	if [ "$show_log_tail" = true ] && have_container; then
		echo "Recent open-webui logs:"
		docker logs --tail 40 open-webui
	fi

	trap - EXIT

	echo "Update completed successfully."
	if [ "$skip_backup" = false ]; then
		echo "Backup reminder: restore with ./scripts/ops/restore-openwebui.sh --archive <backup-file>"
	fi
}

main "$@"
