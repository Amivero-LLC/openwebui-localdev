# AmiChat on Open WebUI (Amivero)

This project packages Amivero’s AmiChat experience on top of Open WebUI, layering in pgvector/PostgreSQL storage, Apache Tika for content extraction, Ollama for local models, and optional Docling for document parsing. The environment is built to

1. Validate Open WebUI features, configurations, and stability before deploying to shared environments.
2. Provide a common, version-controlled configuration that also stores reusable artifacts such as model presets, prompt/user guides, and onboarding notes.
3. Supply scripts for automated testing against the Open WebUI instance so teams can verify integrations and regressions quickly.

It provides a batteries‑included Docker setup, clear lifecycle scripts, and environment presets to get you productive quickly.

## Service Catalog

- [![Open WebUI](https://img.shields.io/badge/Open%20WebUI-Chat%20Interface-0A0A0A?logo=googlechrome&logoColor=white)](https://github.com/open-webui/open-webui) — front-end and API surface for AmiChat.
- [![PostgreSQL](https://img.shields.io/badge/PostgreSQL%20%2B%20pgvector-Vector%20Store-4169E1?logo=postgresql&logoColor=white)](https://github.com/pgvector/pgvector) — persists conversations, embeddings, and metadata.
- [![Apache Tika](https://img.shields.io/badge/Apache%20Tika-Content%20Extraction-D22128?logo=apache&logoColor=white)](https://tika.apache.org/) — default document text extraction engine for RAG workflows.
- [![Ollama](https://img.shields.io/badge/Ollama-Local%20Models-000000?logo=ollama&logoColor=white)](https://ollama.com/) — optional local LLM runtime reachable from Open WebUI.
- [![Docling](https://img.shields.io/badge/Docling-Document%20Parsing-2E7D32?logo=readthedocs&logoColor=white)](https://github.com/docling-project/docling) — alternative parser for rich layout reconstruction (tables, forms).
- [![Docker Compose](https://img.shields.io/badge/Docker%20Compose-Orchestration-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/) — orchestrates the stack for local development.

## Overview

- **Goal:** Build and iterate on Amivero’s AmiChat using Open WebUI, with turnkey backends for chat history, retrieval, and document parsing.
- **Stack:** Docker Compose orchestrating Open WebUI, pgvector/PostgreSQL, Apache Tika, Ollama, and Docling.
- **Ops Scripts:** Simple `up`, `down`, `restart`, and `rebuild` lifecycle commands under `scripts/`.

## Prerequisites

- **Docker Desktop / Docker Engine:** Required to run the stack.
- **Bash shell:** Scripts are POSIX‑ish and tested with Bash.
- **(Optional) Hugging Face token:** Needed for gated models with Docling.

## Quickstart

1) Copy the example environment and adjust values.
- `cp .env.example .env`
- Minimum to set: `OPENAI_API_KEY`/`OPENAI_API_BASE_URLS` (or confirm `OLLAMA_BASE_URL`), and any OAuth secrets (Microsoft client info is intentionally omitted).
- Optional: change `POSTGRES_PASSWORD`, tweak logging toggles, or flip Docling/Tika options.

2) Start the stack.
- `scripts/up.sh` (or `docker compose up -d` / `make up`)
- Open WebUI: `http://localhost:${PORT:-4000}` (default 4000)
- PostgreSQL (pgvector): `localhost:5432` (for debugging)
- Apache Tika health endpoint: `http://localhost:${TIKA_PORT:-9998}/tika`
- Docling UI (if enabled): `http://localhost:${DOCLING_PORT:-5001}`
- Ollama API (internal container): `http://ollama:11434` (use `docker exec` to pull models)

3) Confirm retrieval settings inside Open WebUI.
- If you plan to use Docling instead of Tika, change `CONTENT_EXTRACTION_ENGINE` in `.env` and restart.
- Otherwise, the stack defaults to Apache Tika; test by uploading a document and watching logs.
- In Open WebUI → Admin → Settings ensure `VECTOR_DB=pgvector` and the `PGVECTOR_DB_URL` match the provided defaults.

## System Requirements

- **CPU:** 4 vCPUs minimum (8+ recommended when running Docling parsing and large models).
- **Memory:** 8 GB minimum; 16 GB+ provides smoother RAG and model inference.
- **Disk:** ~10 GB for container layers plus 30 GB `data` volume; allocate extra for Ollama models and PostgreSQL growth.
- **GPU (optional):** Not required, but CUDA-capable GPUs accelerate Ollama or Docling GPU images if you enable them.
- **First launch checklist:**
  - `docker compose pull` to fetch images.
  - `docker compose up -d` to start services.
  - `docker exec -it ollama ollama pull <model>` (or use host Ollama CLI) to preload models before testing.

## Service Ports

| Service | Container | Host Port → Container Port | Purpose |
| --- | --- | --- | --- |
| Open WebUI | `open-webui` | `4000 → 8080` | Chat UI and REST API |
| PostgreSQL + pgvector | `postgres` | `5432 → 5432` | Vector store and metadata DB |
| Apache Tika | `tika` | `9998 → 9998` | Default content extraction service |
| Docling (optional) | `docling` | `5001 → 5001` | Advanced document parser UI/API |
| Ollama (internal) | `ollama` | `— (internal)` | Local LLM runtime (accessible via compose network) |

## Configuration

- Environment file: `.env` (copy from `.env.example`). Key variables include:
- **Open WebUI**: ports, image tag, logging, signup/login toggles, OAuth role settings, RAG & web search flags.
- **Backends**: `PGVECTOR_DB_URL`, `VECTOR_DB`, `OLLAMA_BASE_URL`, `TIKA_SERVER_URL`, optional Docling variables.
- **OAuth**: role management, scopes, and login form options (Microsoft client secrets are intentionally absent).

> **Local development note:** OAuth variables are provided for parity with the Helm chart, but the stack expects OAuth to remain disabled locally (`ENABLE_SIGNUP=false`, `ENABLE_LOGIN_FORM=true`, and no Microsoft client credentials). Enable OAuth only when integrating against the production identity provider.
- Compose services and volumes are defined in `docker-compose.yml`.
- Example values and usage notes live in `.env.example:1`.

## Lifecycle Scripts

All scripts are in `scripts/` and are safe to run from the repo root.

- `scripts/up.sh`: Starts the full stack (Open WebUI, PostgreSQL, Tika, Ollama, Docling); prints endpoints.
- `scripts/down.sh`: Stops and removes containers (volumes preserved).
- `scripts/restart.sh`: Restarts containers in place (no data loss).
- `scripts/rebuild.sh`: Destructive; stops everything, removes volumes, pulls, and recreates containers. Use `--yes` to skip the confirmation.
- `scripts/logs.sh [service…]`: Follows logs for all or the specified services.
- `make up`, `make down`, `make logs`: Shortcuts that wrap the compose commands.

## Backends and Models

- **Ollama (local):** Set `OLLAMA_BASE_URL` in `.env`. The bundled Ollama container serves models inside the compose network; remove the port mapping or adjust `OLLAMA_PORT` if the host already runs Ollama.
- **OpenAI‑compatible:** Set `OPENAI_API_KEY` and `OPENAI_API_BASE_URLS` to use OpenAI or compatible gateways (e.g., Azure OpenAI, BAG, Open WebUI’s OpenAI‑style API).

## Document Extraction with Docling

- Apache Tika is deployed alongside Open WebUI for content extraction and RAG chunking by default.
- Docling can still be enabled (set `CONTENT_EXTRACTION_ENGINE=docling`) for enhanced layouts or table handling.
- Set the Document Extraction backend in Open WebUI to the Docling endpoints noted above.
- Optional gated models (for VLM/picture descriptions) may require `HUGGINGFACE_HUB_TOKEN`.
- The Hugging Face cache is mounted so repeated runs are fast.

## Optional: API Testing Harness

- This repo includes an API testing script for OpenAI‑compatible endpoints at `api-testing/test.sh:1`.
- It can build request payloads and exercise streaming/non‑streaming responses for quick verification across providers.
- Extend or plug these scripts into your CI pipeline to automate smoke or regression testing of the Open WebUI environment.

## Common Tasks

- Start: `scripts/up.sh`
- Stop: `scripts/down.sh`
- Restart: `scripts/restart.sh`
- Rebuild (destructive): `scripts/rebuild.sh --yes`
- Logs: `scripts/logs.sh` (use `scripts/logs.sh open-webui` to filter)

## Troubleshooting

- Port already in use: Adjust `PORT`, `TIKA_PORT`, or `DOCLING_PORT` in `.env`.
- Can’t connect to models: Verify `OLLAMA_BASE_URL` (Ollama container vs host daemon) or `OPENAI_API_*` settings; check `scripts/logs.sh` for errors.
- Database connection errors: Confirm the `postgres` service is healthy and `PGVECTOR_DB_URL` matches your credentials.
- Slow downloads for Docling models: Provide `HUGGINGFACE_HUB_TOKEN` for gated repos and ensure network access.

## Contributing

- Keep scripts small and well‑documented for maintainability.
- Prefer minimal, clear configuration in `.env` and compose overrides as needed.
- Use issues/PRs to propose changes to AmiChat behavior, model defaults, or Docling integration.

---

By default, this setup aims to be simple, reproducible, and team‑friendly so AmiChat development can focus on product experience rather than infrastructure.
