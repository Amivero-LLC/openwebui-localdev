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

if [[ -z "${BASH_VERSION:-}" ]]; then
  exec bash "$0" "$@"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${DEPLOY_ENV_FILE:-.env}"
if [[ "$ENV_FILE" != /* ]]; then
  ENV_FILE="${REPO_ROOT}/${ENV_FILE}"
fi
PROJECT_NAME="${DEPLOYMENT_NAME:-${COMPOSE_PROJECT_NAME:-}}"

if [[ -z "$PROJECT_NAME" ]]; then
  HASH=$(printf "%s" "$REPO_ROOT" | md5 2>/dev/null | sed 's/[^a-fA-F0-9].*//' | head -c6)
  if [[ -z "$HASH" ]]; then
    HASH=$(printf "%s" "$REPO_ROOT" | md5sum 2>/dev/null | awk '{print $1}' | head -c6)
  fi
  PROJECT_NAME="$(basename "$REPO_ROOT")-${HASH:-local}"
fi

COMPOSE_ARGS=(-f "${REPO_ROOT}/docker-compose.yml")
if [[ -f "$ENV_FILE" ]]; then
  COMPOSE_ARGS+=(--env-file "$ENV_FILE")
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
else
  echo "Warning: env file '${ENV_FILE}' not found. Using current environment." >&2
fi
if [[ -n "$PROJECT_NAME" ]]; then
  COMPOSE_ARGS+=(--project-name "$PROJECT_NAME")
fi

echo "Bringing up services (Open WebUI, PostgreSQL, Tika, Ollama, Docling)..."
docker compose "${COMPOSE_ARGS[@]}" up -d

echo "\n✔ Services started. Endpoints:"
echo "  - Open WebUI: http://localhost:${PORT:-4000}"
echo "  - Docling UI: http://localhost:${DOCLING_PORT:-5001} (if enabled)"
echo "  - Apache Tika: http://localhost:${TIKA_PORT:-9998}/tika"
echo "  - PostgreSQL:  host=localhost port=${POSTGRES_PORT:-5432} db=${POSTGRES_DB:-openwebui}"
echo "  - Ollama API:  http://localhost:${OLLAMA_PORT:-11434} (or http://ollama:11434 inside compose)"
echo
docker compose "${COMPOSE_ARGS[@]}" ps
