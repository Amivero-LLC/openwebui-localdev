# AmiChat on Open WebUI (Amivero)

This project packages Amivero’s AmiChat experience on top of Open WebUI, with optional Docling for document extraction. It provides a batteries‑included Docker setup, clear lifecycle scripts, and environment presets to get you productive quickly.

## Overview

- **Goal:** Build and iterate on Amivero’s AmiChat using Open WebUI, with optional Docling for parsing and grounding content from documents.
- **Stack:** Docker Compose orchestrating Open WebUI and Docling, with optional Ollama or OpenAI‑compatible backends.
- **Ops Scripts:** Simple `up`, `down`, `restart`, and `rebuild` lifecycle commands under `scripts/`.

## Prerequisites

- **Docker Desktop / Docker Engine:** Required to run the stack.
- **Bash shell:** Scripts are POSIX‑ish and tested with Bash.
- **(Optional) Hugging Face token:** Needed for gated models with Docling.

## Quickstart

1) Copy the example environment and adjust values.
- `cp .env.example .env`
- Minimum to check: `PORT`, `IMAGE`/`TAG`, `DOCLING_*` if using Docling, and `OPENAI_API_KEY`/`OPENAI_API_BASE_URLS` or `OLLAMA_BASE_URL`.

2) Start the stack.
- `scripts/up.sh`
- Open WebUI: `http://localhost:${PORT:-4000}` (default 4000)
- Docling UI: `http://localhost:${DOCLING_PORT:-5001}` (default 5001)

3) Point Open WebUI to Docling for document extraction.
- In Open WebUI settings, set the Document Extraction backend:
  - Internal URL (from container): `http://docling:5001`
  - Host URL (from your browser): `http://localhost:5001`

## Configuration

- Environment file: `.env` (copy from `.env.example`). Key variables include:
  - **Open WebUI**: `PORT`, `CONTAINER_NAME`, `VOLUME_NAME`, `IMAGE`, `TAG`, `OLLAMA_BASE_URL`, `OPENAI_API_KEY`, `OPENAI_API_BASE_URLS`.
  - **Docling**: `DOCLING_IMAGE`, `DOCLING_TAG`, `DOCLING_CONTAINER_NAME`, `DOCLING_PORT`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME`, `TRANSFORMERS_CACHE`.
- Compose services and volumes are defined in `docker-compose.yml`.
- Example values and usage notes live in `.env.example:1`.

## Lifecycle Scripts

All scripts are in `scripts/` and are safe to run from the repo root.

- `scripts/up.sh`: Starts Open WebUI and Docling; prints endpoints.
- `scripts/down.sh`: Stops and removes containers (volumes preserved).
- `scripts/restart.sh`: Restarts containers in place (no data loss).
- `scripts/rebuild.sh`: Destructive; stops everything, removes volumes, pulls, and recreates containers. Use `--yes` to skip the confirmation.
- `scripts/logs.sh [service…]`: Follows logs for all or the specified services.

## Backends and Models

- **Ollama (local):** Set `OLLAMA_BASE_URL` in `.env`. Open WebUI will route to the local Ollama server for models you’ve pulled.
- **OpenAI‑compatible:** Set `OPENAI_API_KEY` and `OPENAI_API_BASE_URLS` to use OpenAI or compatible gateways (e.g., Azure OpenAI, BAG, Open WebUI’s OpenAI‑style API).

## Document Extraction with Docling

- Docling is deployed alongside Open WebUI for parsing PDFs and other documents.
- Set the Document Extraction backend in Open WebUI to the Docling endpoints noted above.
- Optional gated models (for VLM/picture descriptions) may require `HUGGINGFACE_HUB_TOKEN`.
- The Hugging Face cache is mounted so repeated runs are fast.

## Optional: API Testing Harness

- This repo includes an API testing script for OpenAI‑compatible endpoints at `api-testing/test.sh:1`.
- It can build request payloads and exercise streaming/non‑streaming responses for quick verification across providers.

## Common Tasks

- Start: `scripts/up.sh`
- Stop: `scripts/down.sh`
- Restart: `scripts/restart.sh`
- Rebuild (destructive): `scripts/rebuild.sh --yes`
- Logs: `scripts/logs.sh` (use `scripts/logs.sh open-webui` to filter)

## Troubleshooting

- Port already in use: Adjust `PORT` or `DOCLING_PORT` in `.env`.
- Can’t connect to models: Verify `OLLAMA_BASE_URL` or `OPENAI_API_*` settings; check `scripts/logs.sh` for errors.
- Slow downloads for Docling models: Provide `HUGGINGFACE_HUB_TOKEN` for gated repos and ensure network access.

## Contributing

- Keep scripts small and well‑documented for maintainability.
- Prefer minimal, clear configuration in `.env` and compose overrides as needed.
- Use issues/PRs to propose changes to AmiChat behavior, model defaults, or Docling integration.

---

By default, this setup aims to be simple, reproducible, and team‑friendly so AmiChat development can focus on product experience rather than infrastructure.

