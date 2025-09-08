#!/usr/bin/env bash
# Stop the stack without deleting volumes.
# - Stops and removes containers and networks
# - Keeps persistent data volumes intact
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
