#!/usr/bin/env bash
# Restart the AmiChat services in place.
# - Touches Open WebUI, PostgreSQL, Tika, Ollama, and Docling containers
# - Leaves volumes and images untouched
#
# Usage: scripts/restart.sh

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

echo "Restarting services..."
services_to_restart=()
for svc in open-webui postgres tika ollama docling; do
  if docker compose "${COMPOSE_ARGS[@]}" ps --services 2>/dev/null | grep -qx "$svc"; then
    services_to_restart+=("$svc")
  fi
done

if [ ${#services_to_restart[@]} -gt 0 ]; then
  docker compose "${COMPOSE_ARGS[@]}" restart "${services_to_restart[@]}"
else
  # Fallback if no services detected (e.g., compose config changed)
  docker compose "${COMPOSE_ARGS[@]}" restart
fi

echo "✔ Restart complete."
