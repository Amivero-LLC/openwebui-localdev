#!/usr/bin/env bash
# Restart the Open WebUI + Docling containers in place.
# - Does not recreate containers or touch volumes
#
# Usage: scripts/restart.sh

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

echo "Restarting services..."
# Restart specific services if present; fall back to all
if docker compose ps --services 2>/dev/null | grep -Eq '^open-webui$'; then
  docker compose restart open-webui || true
fi
if docker compose ps --services 2>/dev/null | grep -Eq '^docling$'; then
  docker compose restart docling || true
fi

# If neither matched or to ensure full restart, run generic restart
docker compose restart
echo "✔ Restart complete."
