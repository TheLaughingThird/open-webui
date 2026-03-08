# Open WebUI Local Update Runbook

This runbook documents the repo-tracked update flow for the local Docker Compose deployment in this fork.

Status note:

- March 8, 2026: the local stack was brought back up successfully
- running services confirmed with `docker compose ps`: `comfyui`, `ollama`, and `open-webui`
- `open-webui` reached healthy state on host port `3002` on this workstation

Scope:

- update the running local stack
- create a backup before changes
- rebuild `open-webui` from the current checkout by default
- optionally include the GPU override

Out of scope:

- syncing `main` or `my-local-tweaks` with upstream

For git branch syncing, use:

- `docs/local/openwebui-fork-sync-workflow.md`

## Scripts

- `scripts/ops/update-openwebui.sh`
- `scripts/ops/backup-openwebui.sh`
- `scripts/ops/restore-openwebui.sh`

## Preconditions

1. `.env` exists and contains a stable `WEBUI_SECRET_KEY`
2. Docker Engine is running
3. Your git branch is already at the revision you want to deploy

If you still need to update the fork itself first, do that separately using the fork sync workflow.

## Recommended Command

```bash
./scripts/ops/update-openwebui.sh
```

What it does:

1. loads `.env` from the repo root when present
2. stops `open-webui` briefly for a cleaner backup when it is running
3. creates a timestamped backup of `OPEN_WEBUI_DATA_DIR`
4. pulls updated service images
5. recreates the compose stack
6. rebuilds `open-webui` from the current checkout
7. waits for container and HTTP health checks
8. prints the recent `open-webui` logs

## Restart and Recovery

Use the command that matches the actual compose state:

- if containers already exist and are only stopped, run `make start`
- if containers do not exist yet, run `docker compose up -d`
- if you need to rebuild `open-webui` from the current checkout, run `make startAndBuild`

Recovery note from March 8, 2026:

1. `docker compose start` was not sufficient because no compose containers existed
2. `docker compose up -d` recreated the stack and brought all services back
3. final status was healthy for `open-webui` and up for `ollama` and `comfyui`

## Build Context Permission Note

The local Docker build context must not include runtime data under `./.localdata`.

Why:

- `comfyui` mounts `${COMFYUI_ROOT_DIR-./.localdata/comfyui/root}` as `/root`
- that directory can become root-owned after container use
- `docker compose up -d --build` can then fail while sending the build context with `permission denied`

Mitigation now tracked in this repo:

- `.dockerignore` excludes `.localdata`

If `make startAndBuild` fails with a permission error under `.localdata`, confirm that `.dockerignore` still excludes that directory before changing file ownership.

## Common Variants

### Update with GPU override

```bash
./scripts/ops/update-openwebui.sh --gpu
```

### Skip image pull when only local code changed

```bash
./scripts/ops/update-openwebui.sh --skip-pull
```

### Skip local rebuild and only recreate containers

```bash
./scripts/ops/update-openwebui.sh --no-build
```

### Write backups to a custom location

```bash
./scripts/ops/update-openwebui.sh --backup-dir ./.localdata/backups/manual
```

### Add another compose override

```bash
./scripts/ops/update-openwebui.sh --compose-file docker-compose.otel.yaml
```

## Manual Backup and Restore

Create a backup without updating:

```bash
./scripts/ops/backup-openwebui.sh
```

Restore a backup archive:

```bash
./scripts/ops/restore-openwebui.sh --archive ./.localdata/backups/open-webui/open-webui-data-YYYYMMDDTHHMMSSZ.tar.gz --force
```

Use `--force` only when you intend to replace the current data directory.

## Smoke Test Checklist

Run these checks after an update:

1. `docker compose ps`
2. `curl -fsS http://127.0.0.1:3002/health`
3. log in through the browser
4. open an existing chat and confirm history loads
5. send a test prompt
6. if RAG is used locally, open a knowledge base and confirm files still appear
7. if ComfyUI is enabled, run one image generation test

This repo's current local `.env` uses `OPEN_WEBUI_PORT=3002`. If your `.env` uses a different value, adjust the `curl` command accordingly.

## Rollback Notes

If the update fails because of a bad code change:

1. move the repo back to the previous known-good commit or branch state
2. run `./scripts/ops/update-openwebui.sh --skip-pull`

If the failure is migration or data related:

1. stop the stack
2. restore the backup archive with `restore-openwebui.sh`
3. redeploy the previous known-good code/image state

## Make Targets

The `Makefile` now exposes the same entrypoints:

```bash
make backup-openwebui
make update
make update-gpu
make update-ollama-models
```
