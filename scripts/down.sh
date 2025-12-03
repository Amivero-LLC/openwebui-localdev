#!/usr/bin/env bash
# Stop the AmiChat stack without touching persistent volumes.
# - Halts containers and removes compose networks
# - Leaves data for PostgreSQL, Open WebUI, Docling cache, and Ollama models intact
#
# Usage: scripts/down.sh

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
fi
if [[ -n "$PROJECT_NAME" ]]; then
  COMPOSE_ARGS+=(--project-name "$PROJECT_NAME")
fi

echo "Stopping services (containers only; volumes preserved)..."
docker compose "${COMPOSE_ARGS[@]}" down
echo "✔ Stopped. Data volumes are preserved. Use scripts/rebuild.sh to wipe."
