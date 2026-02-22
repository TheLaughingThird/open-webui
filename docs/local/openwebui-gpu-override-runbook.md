# Open WebUI GPU Override Runbook (`docker-compose.gpu.yaml`)

Status: implementation prep for Phase 2 (RTX 4070 SUPER)

## Purpose

This document prepares the repo for a GPU-enabled compose override without changing the CPU-safe base `docker-compose.yaml`.

Goal:

- Keep `docker-compose.yaml` portable and CPU-safe
- Add NVIDIA-specific settings in `docker-compose.gpu.yaml`
- Enable GPU only for services that benefit from it

## Current Base Compose (This Fork)

Current `docker-compose.yaml` already provides:

- `open-webui`
- `ollama`
- `comfyui` (currently `yanwk/comfyui-boot:cpu`)
- local bind mounts under `./.localdata/`

That means the GPU work should be an override file, not a rewrite of the base compose.

## Recommended Strategy

Use compose layering:

```bash
docker compose -f docker-compose.yaml -f docker-compose.gpu.yaml up -d
```

Why:

- CPU mode still works by default
- GPU mode is explicit
- easier rollback and troubleshooting

## What the GPU Override Should Change

### 1) Open WebUI image tag (optional but recommended)

Switch to a pinned CUDA image when GPU acceleration is needed.

Example:

- `ghcr.io/open-webui/open-webui:vX.Y.Z-cuda`

If you want to keep tag selection in `.env`, use:

- `WEBUI_DOCKER_TAG=vX.Y.Z-cuda`

## 2) GPU access for Ollama

Grant NVIDIA GPU access to `ollama` so local model inference can use the RTX 4070 SUPER.

Practical compose options (varies by Docker/Compose version):

- `gpus: all` (simplest, often works)
- device reservations under `deploy.resources.reservations.devices` (more explicit, less universally honored outside Swarm)

Start with `gpus: all`.

## 3) GPU access for ComfyUI (optional default)

Decision point:

- keep ComfyUI on CPU in base compose (stable default)
- enable GPU in override only when image generation performance matters

This is the recommended split for your fork.

## Suggested `docker-compose.gpu.yaml` (Draft)

Create `docker-compose.gpu.yaml` with the following structure:

```yaml
services:
  ollama:
    gpus: all

  comfyui:
    # Pick a GPU-capable image that matches your preferred ComfyUI setup.
    # Keep this pinned once tested.
    image: yanwk/comfyui-boot:cu124-megapak
    gpus: all

  open-webui:
    # Option A: pin directly here
    image: ghcr.io/open-webui/open-webui:${WEBUI_DOCKER_TAG-vX.Y.Z-cuda}
    gpus: all
```

Notes:

- `comfyui` image tag is an example; choose and pin a GPU-capable tag you verify on your machine.
- `open-webui` GPU access is only needed if you want Open WebUI container-side GPU workloads (for example local pipelines/features that use GPU inside that container). If not needed, you can omit `gpus: all` on `open-webui`.

## Host Prerequisites Checklist (NVIDIA)

Before implementing the override:

1. NVIDIA driver installed on host
2. `nvidia-smi` works on host
3. NVIDIA Container Toolkit installed
4. Docker can expose GPUs to containers

Quick checks:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

If the second command fails, fix host/container toolkit integration before patching compose.

## Implementation Plan (Safe Order)

1. Add `docker-compose.gpu.yaml` with `ollama` GPU access only
2. Test Ollama GPU visibility and inference
3. Add ComfyUI GPU image + GPU access
4. Test image generation in ComfyUI directly
5. Test Open WebUI image generation via ComfyUI integration
6. Optionally enable/pin CUDA tag for `open-webui`

This phased approach makes it obvious which service breaks if something goes wrong.

## Smoke Test Checklist (After Override Exists)

### A) Container status

```bash
docker compose -f docker-compose.yaml -f docker-compose.gpu.yaml ps
```

### B) GPU visibility

Check inside GPU-enabled containers:

```bash
docker exec -it ollama nvidia-smi
docker exec -it comfyui nvidia-smi
```

(`open-webui` only if GPU is enabled there.)

### C) Functional tests

- Ollama model load/inference succeeds
- ComfyUI starts and can generate an image
- Open WebUI can call ComfyUI and return generated image output

## Known Risks / Gotchas

- Floating tags (`latest`, `main`) make GPU regressions harder to debug
- Some compose environments handle `gpus: all` differently; version-specific behavior exists
- ComfyUI GPU image tags may change over time, so pin after validation
- Running both Ollama and ComfyUI on the same GPU can cause VRAM contention

## Decision Defaults for This Fork (Recommended)

- Base compose remains CPU-safe
- GPU override enables:
  - `ollama`: yes
  - `comfyui`: yes (when doing image generation work)
  - `open-webui`: optional (only if a real need is confirmed)
- Pin image tags after first successful end-to-end test

## Next Step After This Doc

Implement `docker-compose.gpu.yaml` and validate with the smoke-test checklist above.
