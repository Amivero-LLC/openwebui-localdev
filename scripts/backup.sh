#!/usr/bin/env bash
set -euo pipefail
mkdir -p backups
TS=$(date +"%Y%m%d-%H%M%S")
docker run --rm \
  -v "${VOLUME_NAME:-open-webui}:/data:ro" \
  -v "$(pwd)/backups:/backups" \
  alpine tar czf "/backups/open-webui-${TS}.tgz" -C /data .
echo "Backup saved to backups/open-webui-${TS}.tgz"