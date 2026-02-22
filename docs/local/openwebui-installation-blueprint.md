# Open WebUI Installation Blueprint (Docker + ddev + NVIDIA)

Status: planning document (phase 0 complete)

## Goals

- Stable local Open WebUI instance with persistent data
- Developer-friendly workflow using `ddev` and Docker Engine
- GPU-capable path for NVIDIA RTX 4070 SUPER
- Repo-tracked knowledge and operational docs that travel with `git clone`
- Repeatable updates with backup/rollback

## Constraints / Assumptions

- Host has Docker Engine installed
- `ddev` is used for local project workflow/routing
- GPU support available via NVIDIA drivers + NVIDIA Container Toolkit
- This repo will contain docs/scripts/config; runtime data remains external or git-ignored

## Recommended Architecture (Best Fit for Your Goal)

### A) Repo-tracked (portable with clone)

Keep these in git:

- `docker-compose.yaml` (base)
- `docker-compose.gpu.yaml` (GPU overrides)
- `.env.example` (sanitized defaults)
- `docs/local/*.md` runbooks/plans
- `scripts/ops/*.sh` backup/update/restore helpers

### B) Persistent runtime data (portable by backup/export, not git)

Store these in Docker named volumes or a bind-mounted host path:

- Open WebUI app data (`/app/backend/data`)
- Ollama model data
- ComfyUI models/input/output (if used)

Recommended local approach:

- Keep named volumes for simplicity during local development
- Add backup/restore scripts to move data between machines
- Optionally switch Open WebUI data to a bind mount later if you want filesystem-level visibility

## Why This Split Matters

`git clone` should give you:

- exact compose config
- exact version tags
- docs and runbooks
- reproducible setup steps

It should not directly carry:

- live SQLite DB contents
- user sessions
- uploaded files
- model caches

Those belong in volumes/backups.

## Phase Plan

## Phase 1: Baseline Persistence + Reproducibility (Do First)

Target outcome: safe updates, persistent sessions/data, versioned docs.

Tasks:

1. Set a persistent `WEBUI_SECRET_KEY` in local `.env`
2. Pin image tags (`WEBUI_DOCKER_TAG`, `OLLAMA_DOCKER_TAG`)
3. Document/update backup + restore commands
4. Document update workflow (`pull -> up -d -> verify`)
5. Add a repo runbook for local `ddev` integration

Success criteria:

- Container can be recreated without data loss
- Users are not logged out due to secret key rotation
- Update and rollback steps are documented and tested

## Phase 2: GPU Enablement (RTX 4070 SUPER)

Target outcome: GPU available to intended services only.

Tasks:

1. Add `docker-compose.gpu.yaml` override
2. Switch Open WebUI image to pinned `-cuda` tag when needed
3. Add GPU reservations (`gpus: all` or compose device reservations)
4. Decide whether ComfyUI should run GPU or CPU by default
5. Add a smoke test checklist (`nvidia-smi`, image generation, model inference)

Success criteria:

- GPU is visible in containers that need it
- No accidental GPU dependency for non-GPU workflows
- Performance tests are documented

## Phase 3: ddev Integration Cleanup

Target outcome: easy local URLs and minimal networking friction.

Tasks:

1. Decide whether `ddev` proxies Open WebUI or runs alongside it
2. Document hostname/port routing (`openwebui.localhost` vs direct port)
3. Ensure reverse proxy headers / auth URLs remain consistent
4. Capture environment variables for local dev (`WEBUI_URL`, auth mode, image gen endpoints)

Success criteria:

- One documented local entrypoint URL
- No confusion between direct port and proxied hostname

## Phase 4: Performance & Scale Readiness (Optional, Later)

Target outcome: prepared path for heavier usage without premature complexity.

When to do this:

- More users
- Heavier RAG ingestion
- Concurrent sessions
- Need better durability/operability

Tasks:

1. Evaluate PostgreSQL migration (from SQLite)
2. Evaluate Redis (only if multi-worker/multi-instance)
3. Choose and standardize a vector DB strategy for RAG
4. Add observability/log rotation and basic metrics

## Installation Pattern Recommendation (Current Best)

Use two compose layers:

- Base compose (`docker-compose.yaml`): portable defaults, CPU-safe, pinned versions
- GPU override (`docker-compose.gpu.yaml`): NVIDIA-specific image tags and device access

Run examples (documented workflow):

```bash
docker compose pull
docker compose up -d
```

GPU mode:

```bash
docker compose -f docker-compose.yaml -f docker-compose.gpu.yaml up -d
```

If `ddev` is only for routing/integration, keep Open WebUI services independent and let `ddev` proxy them.

## Persistence Strategy (Recommended)

### Option 1: Named volumes (recommended first)

Pros:

- simple
- less path-management overhead
- easy to recreate containers

Cons:

- less transparent on-disk layout
- migration to another machine needs export/import step

### Option 2: Bind mounts (later, if desired)

Pros:

- easier manual inspection and backup tooling
- explicit host paths

Cons:

- more path/permissions management
- easier to accidentally share data across incompatible dev/prod setups

## Update Runbook (Short Version)

1. Backup `open-webui` volume
2. Confirm current image tags and secret key
3. `docker compose pull`
4. `docker compose up -d`
5. Check logs for migration errors
6. Smoke test login/chat/RAG/image-gen
7. Keep previous image until validation passes

## Open Questions (Decide Before Patching Compose)

1. Should Open WebUI run behind `ddev` hostname only, or also expose a direct host port?
2. Do you want ComfyUI to default to CPU (stable) or GPU (faster but higher contention)?
3. Do you want local auth enabled (`WEBUI_AUTH=True`) for your main instance?
4. Should persistence remain named volumes, or do you want bind mounts under a git-ignored directory?

## Next Implementation Steps (Recommended Order)

1. Patch compose for persistent `WEBUI_SECRET_KEY` and pinned tags
2. Add `docker-compose.gpu.yaml` override for RTX 4070 SUPER
3. Add `scripts/ops/backup-openwebui.sh` and `scripts/ops/restore-openwebui.sh`
4. Add `docs/local/openwebui-update-runbook.md`
5. Test one full backup -> update -> verify cycle

Phase 2 prep doc (already added):

- `docs/local/openwebui-gpu-override-runbook.md` (GPU override draft, prerequisites, smoke tests)
- `docs/local/openwebui-benchmark-runbook.md` (CPU vs GPU measurement plan and scripts)

## Source References

- Quick Start: <https://docs.openwebui.com/getting-started/quick-start/>
- Updating: <https://docs.openwebui.com/getting-started/updating/>
- Env Configuration: <https://docs.openwebui.com/getting-started/env-configuration/>
- Development: <https://docs.openwebui.com/getting-started/advanced-topics/development/>
- Scaling: <https://docs.openwebui.com/getting-started/advanced-topics/scaling/>
- FAQ: <https://docs.openwebui.com/faq/>
