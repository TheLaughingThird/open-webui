# Open WebUI Fork Sync Workflow (Upstream + Personal Tweaks)

This note documents the recommended Git workflow for this fork:

- Keep `main` as a clean mirror of upstream (`open-webui/open-webui`)
- Keep personal/local changes on a separate branch (for example `my-local-tweaks`)

This makes upstream updates much easier and avoids repeated merge headaches on `main`.

## Branch Model

- `upstream/main`: original Open WebUI project
- `origin/main`: this fork's mirror branch (should stay close to upstream)
- `my-local-tweaks`: personal customizations for local use

## One-Time Setup (Already Done Here)

Add upstream remote:

```bash
git remote add upstream https://github.com/open-webui/open-webui.git
git fetch upstream
```

## Daily/Regular Update Workflow

### 1) Sync fork `main` with upstream

```bash
git switch main
git fetch upstream
git reset --hard upstream/main
git push origin main
```

Notes:

- `git reset --hard upstream/main` is safe here because `main` is intentionally treated as a mirror branch.
- Do not keep personal commits on `main`.

### 2) Rebase personal tweaks on top of the updated `main`

```bash
git switch my-local-tweaks
git rebase main
git push --force-with-lease origin my-local-tweaks
```

Notes:

- Rebase rewrites commit hashes, so pushing the rebased branch requires `--force-with-lease`.
- `--force-with-lease` is safer than `--force` because it refuses to overwrite unexpected remote changes.

## If You Have Local Uncommitted Changes

If your working tree is dirty (for example `docker-compose.gpu.yaml` is modified), stash first:

```bash
git stash push -m "temp-before-sync"
```

Then run the sync/rebase flow, and restore:

```bash
git stash pop
```

## Migrating From "Tweaks on main" (What We Did)

If personal commits were already made on `main`, use this migration pattern:

1. Stash uncommitted changes
2. Create a personal branch from current `main` (for example `my-local-tweaks`)
3. Reset local `main` to `upstream/main`
4. Force-update `origin/main` with `--force-with-lease`
5. Push the personal branch to origin
6. Restore stashed changes on the personal branch

## Why This Works Better

- Upstream sync stays simple (`main` remains a mirror)
- Personal changes remain isolated and easier to reason about
- Fewer conflicts and less branch history confusion over time
