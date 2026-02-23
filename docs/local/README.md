# Local Fork Notes (Workflow + Customizations)

This folder contains local/fork-specific notes for maintaining a personal Open WebUI fork while staying close to upstream.

## Goals for This Fork

- Keep `main` easy to sync with upstream (`open-webui/open-webui`)
- Keep personal changes isolated on a custom branch (currently `my-local-tweaks`)
- Add and validate local GPU support
- Benchmark CPU vs GPU performance before locking in local defaults
- Document local operational decisions to make future updates easier

## Recommended Branch Strategy

- `main`: mirror branch for upstream sync
- `my-local-tweaks`: personal customizations (GPU overrides, local workflows, docs, experiments)

Why:

- Upstream updates stay simple
- Personal commits do not block fork syncs
- Rebasing custom work onto the latest upstream becomes predictable

## Update Workflow (Upstream -> Fork -> Tweaks)

### Sync `main` with upstream

```bash
git switch main
git fetch upstream
git reset --hard upstream/main
git push origin main
```

### Rebase local custom branch on top of updated `main`

```bash
git switch my-local-tweaks
git rebase main
git push --force-with-lease origin my-local-tweaks
```

If you have local uncommitted changes first:

```bash
git stash push -m "temp-before-sync"
# run sync + rebase flow
git stash pop
```

See detailed runbook:

- `docs/local/openwebui-fork-sync-workflow.md`

## GPU Support and Benchmarking Work

### Current local direction

- Add Docker Compose GPU overrides for `ollama`, `comfyui`, and optionally `open-webui`
- Validate host compatibility (drivers/toolkit/image tags)
- Benchmark CPU vs GPU before choosing default local runtime settings

### Related docs

- `docs/local/openwebui-gpu-override-runbook.md`
- `docs/local/openwebui-benchmark-runbook.md`
- `docs/local/openwebui-installation-blueprint.md`

## Planned Local Work (Track Here)

Use this section as a lightweight checklist for fork-specific work that should not live in upstream docs.

- [x] Fork sync workflow documented (`main` mirror + `my-local-tweaks`)
- [x] GPU compose override added for local benchmarking
- [ ] Validate GPU image tags on target host and pin exact versions in `.env`
- [ ] Run CPU vs GPU benchmark comparison and record results in `.localdata/benchmarks/`
- [ ] Decide whether `open-webui` container GPU access should stay enabled by default
- [ ] Add a local smoke-test checklist after compose changes
- [ ] Document upgrade notes when upstream changes affect local overrides

## GitHub Issues vs Docs (Recommended)

Use both, but for different purposes:

- `docs/local/`: stable knowledge (how to update, runbooks, decisions, gotchas, validated commands)
- GitHub Issues: actionable work (tasks, bugs, experiments, follow-ups, results to collect)

Suggested habit:

- Create an issue for a change you want to make (for example GPU validation, benchmark run, override cleanup)
- Do the work on `my-local-tweaks`
- Capture the final process/decision in `docs/local/`
- Link the issue in the relevant doc if it explains why a choice was made

This keeps execution tracking in Issues and long-term knowledge in versioned documentation.

## Notes on README Changes

Keep root `README.md` changes minimal where possible, because this repo tracks upstream and frequent upstream updates can increase merge/rebase noise.

Prefer putting fork-specific operational guidance in `docs/local/` and linking to it from the root README.
