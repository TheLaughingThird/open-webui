# Open WebUI Docs Research Notes (2026-02-22)

Purpose: capture official documentation findings that matter for a developer-friendly, portable, persistent local deployment (`ddev` + Docker Engine + NVIDIA GPU).

## Context (Current Goal)

- Use Open WebUI locally with Docker Engine
- Keep `ddev` for local development routing/workflow
- Use NVIDIA RTX 4070 SUPER for GPU-capable workloads
- Keep setup knowledge/docs in the repo so it travels with `git clone`
- Preserve runtime data across updates/recreates

## Official Sources Reviewed

- Docs home: <https://docs.openwebui.com/>
- Getting Started / Quick Start: <https://docs.openwebui.com/getting-started/quick-start/>
- Updating Open WebUI: <https://docs.openwebui.com/getting-started/updating/>
- Environment Variable Configuration: <https://docs.openwebui.com/getting-started/env-configuration/>
- Local Development Guide: <https://docs.openwebui.com/getting-started/advanced-topics/development/>
- Scaling Open WebUI: <https://docs.openwebui.com/getting-started/advanced-topics/scaling/>
- FAQ: <https://docs.openwebui.com/faq/>
- Features hub: <https://docs.openwebui.com/features/>

## Key Findings (Directly Relevant)

### 1) Persistence is volume-based and mandatory

Open WebUI stores chats/users/uploads in `/app/backend/data`. The docs and FAQ both stress that data survives container recreation only if that path is mounted to a Docker volume/bind mount.

Operational implication:

- Never run without a persistent volume for `/app/backend/data`
- Recreating the container is safe only when the volume is attached

### 2) `WEBUI_SECRET_KEY` must be persistent

The updating guide and FAQ both warn that if `WEBUI_SECRET_KEY` changes between restarts:

- users get logged out
- encrypted secrets (tool/API credentials) may fail to decrypt

Operational implication:

- Set `WEBUI_SECRET_KEY` once and keep it stable across updates/redeploys
- Store it in a local `.env` (not committed) or secret manager

### 3) Docker Compose + GPU is supported, but must be configured explicitly

The Quick Start docs show Docker Compose usage and note that NVIDIA GPU support requires:

- changing image tag from `:main` to `:cuda`
- adding GPU device reservation in compose config

Operational implication:

- Keep a GPU-specific compose override or profile
- Pin a CUDA image tag for reproducible updates

### 4) Use pinned versions for stable/reproducible updates

The Updating guide recommends pinning a specific release version in production instead of floating tags (`:main`, `:cuda`, `:ollama`).

Operational implication:

- Prefer `ghcr.io/open-webui/open-webui:vX.Y.Z-cuda` in your local persistent environment
- Track previous version for rollback

### 5) Backup before updates (especially migrations)

The Updating guide includes explicit backup/restore commands for the `open-webui` Docker volume and warns about migrations.

Operational implication:

- Add a pre-update backup script
- Treat backup + rollback as part of the update workflow, not an optional extra

### 6) `PersistentConfig` env vars can look "ignored"

The Environment Configuration docs explain that many variables are persisted internally after first launch (`PersistentConfig`), and later container restarts may use the stored DB values instead of changed env values.

Operational implication:

- For many settings, use Admin UI after first boot
- If env changes appear ignored, this may be expected behavior
- `ENABLE_PERSISTENT_CONFIG=False` is a temporary override mode, not a normal steady-state config

### 7) Do not share dev and production data

The Local Development Guide explicitly warns not to share DB/data directories between dev and prod because migrations may not be backward compatible.

Operational implication:

- Maintain separate volumes or bind mounts:
  - local-dev/test
  - stable/local-primary

### 8) Scaling path is documented (Postgres -> Redis -> external vector DB)

The Scaling docs clarify defaults and when to move off them:

- SQLite + embedded ChromaDB + single worker is fine for personal/small-team use
- PostgreSQL is required before multi-instance/multi-worker scale
- Redis is required for multi-instance coordination/websocket support
- External vector DB is required for multi-worker/multi-replica RAG uploads

Operational implication:

- For your current single-instance local setup, SQLite is acceptable
- Plan Postgres/Redis only when moving beyond single-worker/single-instance

## What This Means For Your Repo Strategy

There are two different persistence goals:

1. Git-tracked knowledge/config docs (portable with clone)
2. Runtime application data (portable via backup/export, not via git)

Recommended split:

- Put docs, compose files, scripts, and `.env.example` in the repo (git-tracked)
- Keep actual runtime data in Docker volumes or bind mounts (git-ignored)
- Add backup/restore scripts so data can be moved to another machine when needed

## Suggested Next Docs to Add (Repo-Tracked)

- `docs/local/openwebui-installation-blueprint.md`
- `docs/local/openwebui-update-runbook.md`
- `docs/local/openwebui-backup-restore-runbook.md`
- `docs/local/openwebui-env-map.md`
- `docs/local/openwebui-ddev-integration.md`

## Notes About Current Local Compose (Observed)

Current local `docker-compose.yaml` already has:

- named volumes for `open-webui`, `ollama`, `comfyui`
- `WEBUI_SECRET_KEY` present but empty
- `open-webui` image tag controlled by `WEBUI_DOCKER_TAG` (defaults to `main`)
- local `comfyui` image set to CPU (`yanwk/comfyui-boot:cpu`)

Immediate risks:

- empty `WEBUI_SECRET_KEY` (session/tool secret breakage on recreate)
- floating image tags (`main`, `latest`) reduce reproducibility
- no explicit GPU configuration in compose for Open WebUI/Ollama/ComfyUI
