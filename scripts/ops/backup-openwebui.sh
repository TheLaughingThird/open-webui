#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

DEFAULT_DATA_DIR="./.localdata/open-webui"
DEFAULT_BACKUP_DIR="./.localdata/backups/open-webui"

usage() {
	cat <<'EOF'
Usage: ./scripts/ops/backup-openwebui.sh [options]

Creates a timestamped tar.gz backup of the Open WebUI data directory.

Options:
  --source DIR        Override OPEN_WEBUI_DATA_DIR from .env
  --backup-dir DIR    Directory where the archive should be written
  --archive FILE      Exact archive path to create
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

main() {
	require_command tar

	local source_arg=""
	local backup_dir_arg=""
	local archive_arg=""

	while [ $# -gt 0 ]; do
		case "$1" in
			--source)
				source_arg="${2:-}"
				shift 2
				;;
			--backup-dir)
				backup_dir_arg="${2:-}"
				shift 2
				;;
			--archive)
				archive_arg="${2:-}"
				shift 2
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

	cd "$REPO_ROOT"
	load_env_file

	local source_dir="${source_arg:-${OPEN_WEBUI_DATA_DIR:-$DEFAULT_DATA_DIR}}"
	local backup_dir="${backup_dir_arg:-$DEFAULT_BACKUP_DIR}"
	local source_path
	local backup_dir_path
	local archive_path
	local timestamp

	source_path="$(resolve_path "$source_dir")"
	backup_dir_path="$(resolve_path "$backup_dir")"

	if [ ! -d "$source_path" ]; then
		echo "Open WebUI data directory does not exist: $source_path" >&2
		exit 1
	fi

	timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
	if [ -n "$archive_arg" ]; then
		archive_path="$(resolve_path "$archive_arg")"
	else
		archive_path="$backup_dir_path/open-webui-data-$timestamp.tar.gz"
	fi

	mkdir -p "$(dirname "$archive_path")"

	tar -czf "$archive_path" -C "$(dirname "$source_path")" "$(basename "$source_path")"

	echo "Backup created: $archive_path"
}

main "$@"
