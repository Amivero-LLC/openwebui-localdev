#!/usr/bin/env bash
set -euo pipefail
docker exec -it "${CONTAINER_NAME:-open-webui}" bash || docker exec -it "${CONTAINER_NAME:-open-webui}" sh