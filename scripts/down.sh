#!/usr/bin/env bash
# Stop the AmiChat stack without touching persistent volumes.
# - Halts containers and removes compose networks
# - Leaves data for PostgreSQL, Open WebUI, Docling cache, and Ollama models intact
#
# Usage: scripts/down.sh [--env <name>] [--current] [--help]

if [ -z "${BASH_VERSION:-}" ] || [ "${BASH:-}" = "/bin/sh" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deployments.sh
source "${SCRIPT_DIR}/lib/deployments.sh"

usage() {
  cat <<'EOF'
Usage: scripts/down.sh [--env <name>] [--current]
  --env/-e     Target a specific environment
  --current    Skip selection and stop the current environment
EOF
}

SELECTION_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env|-e) SELECTION_ARGS+=("$1" "$2"); shift 2;;
    --current|--no-select) SELECTION_ARGS+=("$1"); shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

select_environment_for_action "stop" "${SELECTION_ARGS[@]}"

echo "Stopping services for '${SELECTED_ENV_NAME}' (project: ${SELECTED_PROJECT_NAME}; volumes preserved)..."
docker compose "${COMPOSE_ARGS[@]}" down
echo "✔ Stopped '${SELECTED_ENV_NAME}'. Data volumes are preserved. Use scripts/rebuild.sh to wipe."
