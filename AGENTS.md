# Repository Guidelines

## Project Structure & Module Organization
This fork combines a SvelteKit frontend with a FastAPI backend. Frontend code lives in `src/`, including routes, UI components, stores, and i18n assets. Backend application code lives in `backend/open_webui/`. End-to-end tests are in `cypress/`, backend fixtures and test assets are in `test/`, static files are in `static/`, and fork-specific runbooks live in `docs/local/`.

## Build, Test, and Development Commands
Use Node 18-22 and Python 3.11-3.12.

- `npm run dev`: start the frontend dev server.
- `cd backend && ./dev.sh`: run the FastAPI backend with reload.
- `npm run build`: create the production frontend build.
- `npm run lint`: run ESLint, Svelte checks, and backend linting.
- `npm run test:frontend`: run Vitest unit tests.
- `make install`, `make start`, `make stop`: manage the local Docker Compose stack.
- `make update` or `./scripts/ops/update-openwebui.sh`: redeploy the local stack from the current checkout.
- `./update.sh`: sync `main` with upstream, rebase `my-local-tweaks`, then redeploy.

## Coding Style & Naming Conventions
Prettier enforces tabs, single quotes, no trailing commas, and a 100-character line width. Follow existing SvelteKit route naming under `src/routes/`, and use descriptive file names such as `workspace-settings.svelte` or `chat-service.ts`. Python changes should remain `black`-compatible and pass `pylint`.

## Testing Guidelines
Use Vitest for frontend logic, Cypress for browser flows, and `pytest` for backend behavior. Name Cypress specs under `cypress/e2e/*.cy.ts`. Add or update tests when behavior changes, and include manual verification steps for UI-sensitive fixes such as chat history, login, or image generation.

## Commit & Pull Request Guidelines
Keep commits concise and scoped; recent history uses prefixes like `fix:`, `docs:`, `feat:`, and `chore:`. Open PRs against `dev`, not `main`. PRs should include a clear summary, linked issue when applicable, test evidence, and screenshots or video for UI changes. Keep `main` as an upstream mirror and do personal work on `my-local-tweaks`.

## Configuration & Operations Tips
Keep secrets in `.env`, especially a stable `WEBUI_SECRET_KEY`. Before major updates, use the backup and restore scripts in `scripts/ops/`. Refer to `docs/local/openwebui-update-runbook.md` and `docs/local/openwebui-fork-sync-workflow.md` for the fork-specific maintenance workflow.
