#!/usr/bin/env bash
# Tail logs for the stack.
# - Shows logs from all services (Open WebUI, Docling)
# - Follows output until interrupted (Ctrl+C)
#
# Usage: scripts/logs.sh [service...]
#   If service names are provided, follows only those logs.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  docker compose logs -f "$@"
else
  docker compose logs -f
fi
