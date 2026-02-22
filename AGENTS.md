# Repository Guidelines

## Project Structure & Module Organization
This repository is a full-stack project with a SvelteKit frontend and FastAPI backend.

- `src/`: frontend app code (routes, UI components, utilities, i18n).
- `backend/open_webui/`: Python API/server logic and backend utilities.
- `cypress/`: end-to-end browser tests.
- `test/`: backend test assets and fixtures.
- `static/`: static files (images, fonts, PWA assets, themes).
- `docs/`: contributor and security documentation.

## Build, Test, and Development Commands
Use Node 18-22 and Python 3.11-3.12.

- `npm run dev`: starts frontend dev server (includes Pyodide prep).
- `npm run build`: production frontend build via Vite.
- `npm run preview`: preview built frontend.
- `npm run lint`: runs frontend ESLint, Svelte type checks, and backend pylint.
- `npm run format` and `npm run format:backend`: format JS/TS/Svelte/CSS/MD and Python.
- `npm run test:frontend`: runs Vitest unit tests.
- `npm run cy:open`: opens Cypress test runner.
- `cd backend && ./dev.sh`: runs backend locally with auto-reload.
- `make install|start|stop`: manage Docker Compose-based local stack.

## Coding Style & Naming Conventions
- Prettier config uses tabs, single quotes, no trailing commas, 100-char line width.
- ESLint covers TypeScript, Svelte, and Cypress conventions.
- Python code should pass `black` and `pylint`.
- Prefer descriptive file names and keep route organization aligned with SvelteKit conventions (for example, `src/routes/(app)/workspace/...`).

## Testing Guidelines
- Frontend unit tests: Vitest (`npm run test:frontend`).
- E2E tests: Cypress specs in `cypress/e2e/*.cy.ts`.
- Backend tests live under `backend/open_webui/test/`; run `pytest` when changing backend behavior.
- Add or update tests for behavior changes; include manual verification steps for UI-sensitive fixes.

## Commit & Pull Request Guidelines
- Follow concise, scoped commit messages (history commonly uses prefixes like `refac`, `chore: format`).
- Open PRs against `dev` (not `main`).
- Use a PR title prefix from template taxonomy (`fix`, `feat`, `refactor`, `docs`, etc.).
- Complete the PR checklist: clear description, changelog entry, docs updates, test evidence, and screenshots/videos for UI changes.
- Keep PRs atomic and rebase/clean up commits before review.
