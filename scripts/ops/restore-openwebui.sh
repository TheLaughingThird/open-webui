#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

DEFAULT_DATA_DIR="./.localdata/open-webui"

usage() {
	cat <<'EOF'
Usage: ./scripts/ops/restore-openwebui.sh --archive FILE [options]

Restores an Open WebUI backup archive created by backup-openwebui.sh.

Options:
  --archive FILE      Backup archive to restore
  --target DIR        Override OPEN_WEBUI_DATA_DIR from .env
  --force             Replace an existing target directory
  -h, --help          Show this help text
EOF
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
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

load_env_file() {
	if [ -f "$ENV_FILE" ]; then
		set -a
		# shellcheck disable=SC1090
		. "$ENV_FILE"
		set +a
	fi
}

target_has_files() {
	local target="$1"
	find "$target" -mindepth 1 -maxdepth 1 | read -r _
}

main() {
	require_command tar

	local archive_arg=""
	local target_arg=""
	local force_restore=false

	while [ $# -gt 0 ]; do
		case "$1" in
			--archive)
				archive_arg="${2:-}"
				shift 2
				;;
			--target)
				target_arg="${2:-}"
				shift 2
				;;
			--force)
				force_restore=true
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

	if [ -z "$archive_arg" ]; then
		echo "--archive is required" >&2
		usage >&2
		exit 1
	fi

	cd "$REPO_ROOT"
	load_env_file

	local archive_path
	local target_dir
	local target_path
	local target_parent
	local archive_root
	local target_basename

	archive_path="$(resolve_path "$archive_arg")"
	target_dir="${target_arg:-${OPEN_WEBUI_DATA_DIR:-$DEFAULT_DATA_DIR}}"
	target_path="$(resolve_path "$target_dir")"

	if [ ! -f "$archive_path" ]; then
		echo "Backup archive not found: $archive_path" >&2
		exit 1
	fi

	target_parent="$(dirname "$target_path")"
	target_basename="$(basename "$target_path")"
	mkdir -p "$target_parent"

	if [ -d "$target_path" ] && target_has_files "$target_path"; then
		if [ "$force_restore" = false ]; then
			echo "Target directory is not empty: $target_path" >&2
			echo "Use --force to replace it." >&2
			exit 1
		fi

		rm -rf "$target_path"
	fi

	archive_root="$(tar -tzf "$archive_path" | head -n 1 | cut -d/ -f1)"
	if [ -z "$archive_root" ]; then
		echo "Could not determine archive root from: $archive_path" >&2
		exit 1
	fi

	tar -xzf "$archive_path" -C "$target_parent"

	if [ "$archive_root" != "$target_basename" ]; then
		rm -rf "$target_path"
		mv "$target_parent/$archive_root" "$target_path"
	fi

	echo "Backup restored to: $target_path"
}

main "$@"
