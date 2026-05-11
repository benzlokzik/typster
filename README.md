# Typster

[![CLA assistant](https://cla-assistant.io/readme/badge/typster-io/typster)](https://cla-assistant.io/typster-io/typster)
[![CI](https://github.com/typster-io/typster/actions/workflows/ci.yml/badge.svg)](https://github.com/typster-io/typster/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/elixir-%3E%3D1.19-4B275F?logo=elixir)](https://elixir-lang.org)
[![Erlang/OTP](https://img.shields.io/badge/erlang%2FOTP-%3E%3D28-A90533?logo=erlang)](https://www.erlang.org)
[![Bun](https://img.shields.io/badge/bun-%3E%3D1.3-fbf0df?logo=bun)](https://bun.sh)
[![Conventional Commits](https://img.shields.io/badge/commits-conventional-FE5196?logo=conventionalcommits)](https://www.conventionalcommits.org)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL%20v3-blue)](./LICENSE)
[![Pixi](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/prefix-dev/pixi/main/assets/badge/v0.json)](https://pixi.sh)
[![Dev Containers](https://img.shields.io/badge/dev_containers-supported-0078D4?logo=docker)](https://containers.dev)
[![Phoenix LiveView](https://img.shields.io/badge/Phoenix_LiveView-1.1.28-FD4F00?logo=phoenixframework)](https://hexdocs.pm/phoenix_live_view)

**The [Typst](https://typst.app) editor for writing that ships.**

Typst is a modern LaTeX alternative — a markup-based language for producing beautiful, structured documents. Typster is the browser IDE around it: a polished three-pane editor (files · source · live preview) with cloud projects, auto-save, keyboard-first UX, and zero install. Write Typst, compile to PDF in ~200 ms, share a link.

| Light | Dark |
|---|---|
| <img width="3248" height="2122" alt="image" src="https://github.com/user-attachments/assets/c230e505-ee44-4167-8b1a-15b9c7bc5e74" /> | <img width="3248" height="2122" alt="image" src="https://github.com/user-attachments/assets/53416a43-0e45-4cd2-b8de-87eff6d9965d" /> |
| <img width="3248" height="2122" alt="image" src="https://github.com/user-attachments/assets/0f52cd1e-7509-4510-864a-c688e1fd65cb" /> | <img width="3248" height="2122" alt="image" src="https://github.com/user-attachments/assets/3cf14b0b-c549-409a-b5d1-b94cf986f97d" /> |


---

## Stack

| Layer | Technology |
|---|---|
| Backend | Elixir 1.19 + Phoenix 1.8 + LiveView 1.1 on BEAM (Erlang/OTP 28) |
| Frontend | Bun 1.3 · Tailwind CSS · salad_ui components |
| Database | PostgreSQL 16 (Ecto) |
| Object storage | MinIO (S3-compatible) |
| Background jobs | Oban 2.17 |
| Testing | ExUnit · Playwright (browser E2E) |
| Dev environment | Pixi · prek · Docker Compose |

---

## Quick start

The fastest way to run Typster is with Docker. Everything runs in containers — no toolchain setup needed.

```bash
docker compose up
```

Open [http://localhost:4000](http://localhost:4000)

That's it. Docker Compose starts PostgreSQL, MinIO, and the app together. The app container waits for both services to be healthy before booting

> Looking to set up a local dev environment, use Pixi, or work inside a Dev Container? See [CONTRIBUTING.md](CONTRIBUTING.md)

---

## Running tests

```bash
mix test                        # Elixir unit tests
cd assets && bun run test:e2e   # Browser E2E tests (Playwright)
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide — dev workflow, code style, commit conventions, and design system reference

**Quick checklist before opening a PR:**

- prek runs automatically on commit (pre-commit hooks). Fix any failures before pushing
- Run `mix precommit` manually to catch compile warnings, unused deps, formatting, and test failures
- Follow [Conventional Commits](https://www.conventionalcommits.org) (TODO —  enforced on `main` by GitHub rulesets)
- Keep CSS changes consistent with the `--mk-*` design tokens in `assets/css/app.css`
