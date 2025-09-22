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

echo "Stopping services (containers only; volumes preserved)..."
docker compose down
echo "✔ Stopped. Data volumes are preserved. Use scripts/rebuild.sh to wipe."
