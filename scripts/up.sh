#!/usr/bin/env bash
set -euo pipefail
docker compose up -d
echo "Open WebUI should be up at http://localhost:${PORT:-4000}"