#!/usr/bin/env bash
# Restart the AmiChat services in place.
# - Touches Open WebUI, PostgreSQL, Tika, Ollama, and Docling containers
# - Leaves volumes and images untouched
#
# Usage: scripts/restart.sh [--env <name>] [--current] [--help]

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
Usage: scripts/restart.sh [--env <name>] [--current]
  --env/-e     Target a specific environment
  --current    Skip selection and restart the current environment
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

select_environment_for_action "restart" "${SELECTION_ARGS[@]}"

echo "Restarting services for '${SELECTED_ENV_NAME}'..."
services_to_restart=()
for svc in open-webui postgres tika ollama docling; do
  if docker compose "${COMPOSE_ARGS[@]}" ps --services 2>/dev/null | grep -qx "$svc"; then
    services_to_restart+=("$svc")
  fi
done

if [ ${#services_to_restart[@]} -gt 0 ]; then
  docker compose "${COMPOSE_ARGS[@]}" restart "${services_to_restart[@]}"
else
  # Fallback if no services detected (e.g., compose config changed)
  docker compose "${COMPOSE_ARGS[@]}" restart
fi

record_current_env "$SELECTED_ENV_NAME"

echo "✔ Restart complete."
