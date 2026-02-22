# Open WebUI Local Benchmark Runbook (CPU vs GPU)

Status: prep document for measuring whether GPU mode is worth it on this fork

## Goal

Measure real performance differences between CPU mode and GPU mode for:

- `ollama` inference
- `comfyui` image generation
- optional end-to-end checks through Open WebUI

This avoids guessing and makes the `docker-compose.gpu.yaml` work evidence-based.

## What to Benchmark (Important)

GPU impact is not the same for every component:

- `Open WebUI` (web app/backend): usually little direct GPU benefit
- `ollama`: often significant latency/throughput improvement
- `comfyui`: usually the biggest improvement for image generation

Start by benchmarking `ollama` and `comfyui` directly.

## Benchmark Principles (Keep It Fair)

Use the same inputs for CPU and GPU runs:

- same model
- same prompt(s)
- same image workflow
- same seed
- same steps
- same resolution
- same machine
- no other heavy GPU jobs running

Run multiple repetitions (at least 3) and compare averages/medians.

## Files Added for This Runbook

- `scripts/ops/benchmark-ollama.sh`
- `scripts/ops/benchmark-comfyui.sh`

These scripts log simple CSV-style timing rows and are intended for local comparison runs.

## Prerequisites

### CPU baseline

- Base compose only:

```bash
docker compose up -d
```

### GPU comparison

- GPU override implemented and tested (see `docs/local/openwebui-gpu-override-runbook.md`)
- NVIDIA stack working (`nvidia-smi`)

```bash
docker compose -f docker-compose.yaml -f docker-compose.gpu.yaml up -d
```

## 1) Ollama Benchmark (Direct API)

### Example CPU run

```bash
MODE_LABEL=cpu \
OLLAMA_MODEL=llama3.2:3b \
RUNS=5 \
OUTFILE=./.localdata/benchmarks/ollama.csv \
scripts/ops/benchmark-ollama.sh
```

### Example GPU run

```bash
MODE_LABEL=gpu \
OLLAMA_MODEL=llama3.2:3b \
RUNS=5 \
OUTFILE=./.localdata/benchmarks/ollama.csv \
scripts/ops/benchmark-ollama.sh
```

### Result format

CSV columns:

- `timestamp`
- `mode`
- `run`
- `model`
- `total_seconds`
- `http_code`

Primary metric for first pass:

- lower `total_seconds` is better

## 2) ComfyUI Benchmark (Direct API)

This script submits the same API workflow file repeatedly and measures total completion time.

### Prepare a stable workflow JSON

Requirements:

- exported in ComfyUI API format
- fixed seed
- fixed model
- fixed steps
- fixed width/height

Tip:

- keep a dedicated benchmark workflow file such as `docs/local/benchmarks/comfyui-benchmark-workflow.json` (optional path; do not commit large/generated variants if they change often)

### Example CPU run

```bash
MODE_LABEL=cpu \
WORKFLOW_FILE=/path/to/comfyui-benchmark-workflow.json \
RUNS=3 \
OUTFILE=./.localdata/benchmarks/comfyui.csv \
scripts/ops/benchmark-comfyui.sh
```

### Example GPU run

```bash
MODE_LABEL=gpu \
WORKFLOW_FILE=/path/to/comfyui-benchmark-workflow.json \
RUNS=3 \
OUTFILE=./.localdata/benchmarks/comfyui.csv \
scripts/ops/benchmark-comfyui.sh
```

### Result format

CSV columns:

- `timestamp`
- `mode`
- `run`
- `workflow_file`
- `total_seconds`
- `status`

Primary metric:

- lower `total_seconds` is better

## 3) Optional End-to-End Check in Open WebUI

After direct service benchmarks, do a sanity check in the UI:

- prompt response feels faster with Ollama GPU
- image generation in Open WebUI via ComfyUI completes faster
- no integration regressions after switching to GPU override

This is useful for user experience validation, but direct service timings are more reliable for comparison.

## Recommended Test Matrix (First Pass)

1. `ollama` CPU vs GPU with one small model (fast signal)
2. `ollama` CPU vs GPU with one larger model (bigger difference likely)
3. `comfyui` CPU vs GPU with one standard workflow (512x512)
4. `comfyui` CPU vs GPU with one heavier workflow (optional)

## How to Read Results (Practical)

Good outcome:

- GPU is consistently faster across runs (not just one run)
- improvements are large enough to justify extra setup complexity
- no crashes / VRAM issues under your normal workload

Potential reason to stay CPU for some services:

- GPU contention between `ollama` and `comfyui`
- unstable image tags/drivers
- only small benefit for your real usage patterns

## Next Step After Benchmarking

Use the results to finalize `docker-compose.gpu.yaml` defaults:

- `ollama` GPU on/off
- `comfyui` GPU on/off by default
- `open-webui` CUDA image and GPU access (only if needed)
