#!/usr/bin/env bash
# Rebuild (delete and recreate) the Open WebUI + Docling environment.
# - Stops containers
# - Removes networks and declared volumes (data loss!)
# - Pulls latest images (respecting .env IMAGE/TAG, DOCLING_IMAGE/TAG)
# - Recreates containers fresh
#
# Usage:
#   scripts/rebuild.sh [--yes]
#     --yes   Proceed without interactive confirmation (destructive)

set -euo pipefail

CONFIRM="ask"
if [[ "${1:-}" == "--yes" ]]; then
  CONFIRM="yes"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

warn() { printf "\033[33m%s\033[0m\n" "$*"; }

warn "This will DELETE volumes and all application data."
warn "Volume to be removed: ${VOLUME_NAME:-open-webui} (and docling-cache)"

if [[ "$CONFIRM" == "ask" ]]; then
  if [ -t 0 ]; then
    read -r -p "Proceed with destructive rebuild? [y/N] " ans
    case "$ans" in
      y|Y|yes|YES) : ;; 
      *) echo "Aborted."; exit 1;;
    esac
  else
    echo "Non-interactive shell. Re-run with --yes to confirm destructive rebuild." >&2
    exit 1
  fi
fi

echo "Stopping and removing containers, networks, and volumes..."
docker compose down -v --remove-orphans

# Attempt to remove the named data volume explicitly (ignore errors)
docker volume rm "${VOLUME_NAME:-open-webui}" >/dev/null 2>&1 || true

echo "Pulling latest images..."
docker compose pull

echo "Recreating containers..."
docker compose up -d --force-recreate

echo
echo "✔ Rebuild complete. Endpoints:"
echo "  - Open WebUI: http://localhost:${PORT:-4000}"
echo "  - Docling:    http://localhost:${DOCLING_PORT:-5001}"
echo
docker compose ps

