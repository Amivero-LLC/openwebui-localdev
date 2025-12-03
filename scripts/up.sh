#!/usr/bin/env bash
# Start the full AmiChat stack (Open WebUI, PostgreSQL, pgvector, Tika, Ollama, Docling).
# - Lists configured environments, defaults to the current one, and starts it
# - Marks the started environment as the current environment
#
# Usage: scripts/up.sh [--env <name>] [--current] [--help]
#   --env/-e     Use a specific environment (deployments/<name>.env or .env)
#   --current    Skip selection and use the current environment
#   --help/-h    Show help

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/deployments.sh
source "${SCRIPT_DIR}/lib/deployments.sh"

usage() {
  cat <<'EOF'
Usage: scripts/up.sh [--env <name>] [--current] [--help]
  --env/-e     Use a specific environment (deployments/<name>.env or .env)
  --current    Skip selection and use the current environment
  --help/-h    Show this message
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

select_environment_for_action "start" "${SELECTION_ARGS[@]}"

echo "Bringing up '${SELECTED_ENV_NAME}' (project: ${SELECTED_PROJECT_NAME})..."
docker compose "${COMPOSE_ARGS[@]}" up -d

record_current_env "$SELECTED_ENV_NAME"

echo
echo "✔ Services started for '${SELECTED_ENV_NAME}'. Endpoints:"
echo "  - Open WebUI: http://localhost:${SELECTED_PORT:-4000}"
echo "  - Docling UI: http://localhost:${SELECTED_DOCLING_PORT:-5001} (if enabled)"
echo "  - Apache Tika: http://localhost:${SELECTED_TIKA_PORT:-9998}/tika"
echo "  - PostgreSQL:  host=localhost port=${SELECTED_POSTGRES_PORT:-5432} db=${POSTGRES_DB:-openwebui}"
echo "  - Ollama API:  http://localhost:${SELECTED_OLLAMA_PORT:-11434} (or http://ollama:11434 inside compose)"
echo
docker compose "${COMPOSE_ARGS[@]}" ps
