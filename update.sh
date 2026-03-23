#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
TWEAKS_BRANCH="${TWEAKS_BRANCH:-my-local-tweaks}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
ORIGIN_REMOTE="${ORIGIN_REMOTE:-origin}"
RUNTIME_UPDATE_SCRIPT="${RUNTIME_UPDATE_SCRIPT:-$REPO_ROOT/scripts/ops/update-openwebui.sh}"
PUSH_MAIN=true
PUSH_TWEAKS=true
SYNC_TWEAKS=true
DEPLOY_STACK=true
DEPLOY_GPU=false
AUTO_STASH=false
STASH_NAME="update-sh-$(date -u +%Y%m%dT%H%M%SZ)"
ORIGINAL_BRANCH=""
STASH_CREATED=false

usage() {
	cat <<EOF
Usage: ./update.sh [options]

Sync this fork with upstream and optionally rebase the local tweaks branch.

Default flow:
  1. fetch $UPSTREAM_REMOTE and $ORIGIN_REMOTE
  2. reset $MAIN_BRANCH to $UPSTREAM_REMOTE/$MAIN_BRANCH
  3. push $MAIN_BRANCH to $ORIGIN_REMOTE
  4. rebase $TWEAKS_BRANCH on top of $MAIN_BRANCH
  5. push $TWEAKS_BRANCH with --force-with-lease
  6. run the local Docker deployment update

Options:
  --main-only         Sync only $MAIN_BRANCH
  --no-push-main      Do not push $MAIN_BRANCH to $ORIGIN_REMOTE
  --no-push-tweaks    Do not push $TWEAKS_BRANCH after rebase
  --no-deploy         Skip the local Docker deployment update
  --gpu               Run the deployment update with GPU override
  --stash             Auto-stash and restore local uncommitted changes
  -h, --help          Show this help text

Environment overrides:
  MAIN_BRANCH, TWEAKS_BRANCH, UPSTREAM_REMOTE, ORIGIN_REMOTE, RUNTIME_UPDATE_SCRIPT
EOF
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

cleanup() {
	local exit_code="$?"

	if [ "$STASH_CREATED" = true ]; then
		git switch "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
		if ! git stash pop --index >/dev/null 2>&1; then
			echo "Warning: stash restore needs manual attention. Run: git stash list" >&2
		fi
	fi

	exit "$exit_code"
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--main-only)
				SYNC_TWEAKS=false
				shift
				;;
			--no-push-main)
				PUSH_MAIN=false
				shift
				;;
			--no-push-tweaks)
				PUSH_TWEAKS=false
				shift
				;;
			--no-deploy)
				DEPLOY_STACK=false
				shift
				;;
			--gpu)
				DEPLOY_GPU=true
				shift
				;;
			--stash)
				AUTO_STASH=true
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
}

ensure_clean_or_stash() {
	if git diff --quiet && git diff --cached --quiet; then
		return 0
	fi

	if [ "$AUTO_STASH" != true ]; then
		echo "Working tree has uncommitted changes." >&2
		echo "Commit or stash them first, or rerun with: ./update.sh --stash" >&2
		exit 1
	fi

	ORIGINAL_BRANCH="$(git branch --show-current)"
	git stash push --include-untracked -m "$STASH_NAME" >/dev/null
	STASH_CREATED=true
}

verify_branch_exists() {
	local branch="$1"
	if ! git show-ref --verify --quiet "refs/heads/$branch"; then
		echo "Local branch not found: $branch" >&2
		exit 1
	fi
}

verify_remote_exists() {
	local remote="$1"
	if ! git remote get-url "$remote" >/dev/null 2>&1; then
		echo "Git remote not found: $remote" >&2
		exit 1
	fi
}

verify_runtime_update_script() {
	if [ ! -f "$RUNTIME_UPDATE_SCRIPT" ]; then
		echo "Runtime update script not found: $RUNTIME_UPDATE_SCRIPT" >&2
		exit 1
	fi
}

sync_main_branch() {
	echo "Fetching remotes..."
	git fetch "$UPSTREAM_REMOTE"
	git fetch "$ORIGIN_REMOTE"

	echo "Syncing $MAIN_BRANCH to $UPSTREAM_REMOTE/$MAIN_BRANCH..."
	git switch "$MAIN_BRANCH"
	git reset --hard "$UPSTREAM_REMOTE/$MAIN_BRANCH"

	if [ "$PUSH_MAIN" = true ]; then
		echo "Pushing $MAIN_BRANCH to $ORIGIN_REMOTE..."
		git push "$ORIGIN_REMOTE" "$MAIN_BRANCH"
	fi
}

sync_tweaks_branch() {
	echo "Rebasing $TWEAKS_BRANCH on top of $MAIN_BRANCH..."
	git switch "$TWEAKS_BRANCH"
	git rebase "$MAIN_BRANCH"

	if [ "$PUSH_TWEAKS" = true ]; then
		echo "Pushing $TWEAKS_BRANCH to $ORIGIN_REMOTE with --force-with-lease..."
		git push --force-with-lease "$ORIGIN_REMOTE" "$TWEAKS_BRANCH"
	fi
}

deploy_runtime() {
	local deploy_args=()

	if [ "$DEPLOY_GPU" = true ]; then
		deploy_args+=(--gpu)
	fi

	if [ "$STASH_CREATED" = true ]; then
		echo "Note: local uncommitted changes were stashed and are not included in this deployment."
	fi

	echo "Updating local Docker deployment..."
	bash "$RUNTIME_UPDATE_SCRIPT" "${deploy_args[@]}"
}

main() {
	require_command git
	require_command bash
	parse_args "$@"

	cd "$REPO_ROOT"

	verify_remote_exists "$UPSTREAM_REMOTE"
	verify_remote_exists "$ORIGIN_REMOTE"
	verify_branch_exists "$MAIN_BRANCH"
	if [ "$DEPLOY_STACK" = true ]; then
		verify_runtime_update_script
	fi

	if [ "$SYNC_TWEAKS" = true ]; then
		verify_branch_exists "$TWEAKS_BRANCH"
	fi

	trap cleanup EXIT
	ensure_clean_or_stash
	sync_main_branch

	if [ "$SYNC_TWEAKS" = true ]; then
		sync_tweaks_branch
	fi

	if [ "$DEPLOY_STACK" = true ]; then
		deploy_runtime
	fi

	if [ "$STASH_CREATED" = false ]; then
		echo "Done."
	else
		echo "Done. Restoring stashed changes..."
	fi
}

main "$@"
