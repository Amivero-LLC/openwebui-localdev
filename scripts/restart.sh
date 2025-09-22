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

echo "Restarting services..."
services_to_restart=()
for svc in open-webui postgres tika ollama docling; do
  if docker compose ps --services 2>/dev/null | grep -qx "$svc"; then
    services_to_restart+=("$svc")
  fi
done

if [ ${#services_to_restart[@]} -gt 0 ]; then
  docker compose restart "${services_to_restart[@]}"
else
  # Fallback if no services detected (e.g., compose config changed)
  docker compose restart
fi

echo "✔ Restart complete."
