#!/usr/bin/env bash
# Start the full AmiChat stack (Open WebUI, PostgreSQL, pgvector, Tika, Ollama, Docling).
# - Brings up every service declared in docker-compose.yml
# - Surfaces key endpoints so you can smoke-test the deployment quickly
#
# Usage: scripts/up.sh

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

echo "Bringing up services (Open WebUI, PostgreSQL, Tika, Ollama, Docling)..."
docker compose up -d

echo "\n✔ Services started. Endpoints:"
echo "  - Open WebUI: http://localhost:${PORT:-4000}"
echo "  - Docling UI: http://localhost:${DOCLING_PORT:-5001} (if enabled)"
echo "  - Apache Tika: http://localhost:${TIKA_PORT:-9998}/tika"
echo "  - PostgreSQL:  host=localhost port=5432 db=${POSTGRES_DB:-openwebui}"
echo "  - Ollama API:  http://ollama:11434 (within the compose network)"
echo
docker compose ps
