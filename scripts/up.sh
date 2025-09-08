#!/usr/bin/env bash
# Start the Open WebUI + Docling stack.
# - Brings up all services in docker-compose.yml
# - Prints helpful endpoints on success
#
# Usage: scripts/up.sh

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

echo "Bringing up services (Open WebUI, Docling)..."
docker compose up -d

echo "\n✔ Services started. Endpoints:"
echo "  - Open WebUI: http://localhost:${PORT:-4000}"
echo "  - Docling:    http://localhost:${DOCLING_PORT:-5001}"
echo
docker compose ps
