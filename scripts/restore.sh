#!/usr/bin/env bash
set -euo pipefail
FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: scripts/restore.sh backups/open-webui-YYYYMMDD-HHMMSS.tgz"
  exit 1
fi
docker run --rm \
  -v "${VOLUME_NAME:-open-webui}:/data" \
  -v "$(pwd):/host" \
  alpine sh -c "rm -rf /data/* && tar xzf /host/${FILE} -C /data"
echo "Restored ${FILE} into volume ${VOLUME_NAME:-open-webui}"