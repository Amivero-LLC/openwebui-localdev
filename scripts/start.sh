#!/usr/bin/env bash
# Smart start helper: finds an open Open WebUI port block (4000, 4010, 4020, ...)
# and then delegates to scripts/deploy.sh to launch the stack on that block.

set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
  exec bash "$0" "$@"
fi

usage() {
  cat <<'EOF'
Usage: scripts/start.sh [--name <deployment>]
       Automatically picks a free port block (4000, 4010, 4020, ...)
       and starts the Open WebUI stack on it.
EOF
}

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-local}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|-n) DEPLOYMENT_NAME="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_SCRIPT="${REPO_ROOT}/scripts/deploy.sh"
ENV_FILE="${REPO_ROOT}/deployments/${DEPLOYMENT_NAME}.env"

echo "Checking for existing Open WebUI deployments..."
existing_containers="$(docker ps --format '{{.Names}}\t{{.Ports}}' | grep -Ei 'open-webui' || true)"
if [[ -n "$existing_containers" ]]; then
  echo "$existing_containers"
else
  echo "No running Open WebUI containers detected."
fi
[[ -f "$ENV_FILE" ]] && echo "Found env file for '${DEPLOYMENT_NAME}': ${ENV_FILE}"

port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -PiTCP -sTCP:LISTEN -n -P -t :"$port" >/dev/null 2>&1 && return 0
  else
    netstat -an 2>/dev/null | grep "[.:]${port}[[:space:]]" | grep -i listen >/dev/null 2>&1 && return 0
  fi

  if docker ps --format '{{.Ports}}' 2>/dev/null | tr ',' '\n' | grep -E "(:|->)${port}(/tcp|/udp|$)" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

block_available() {
  local base="$1"
  local offsets=(0 1 2 3 4)
  for offset in "${offsets[@]}"; do
    local port=$((base + offset))
    if port_in_use "$port"; then
      return 1
    fi
  done
  return 0
}

MAX_BLOCK_ATTEMPTS=100

find_free_block() {
  local base="${1:-4000}"
  local step=10
  local attempts=0
  while (( attempts < MAX_BLOCK_ATTEMPTS )); do
    if block_available "$base"; then
      echo "$base"
      return 0
    fi
    base=$((base + step))
    attempts=$((attempts + 1))
  done
  return 1
}

START_BASE="${PORT_BLOCK_BASE:-4000}"
CHOSEN_BASE="$(find_free_block "$START_BASE")" || {
  echo "Error: could not find a free port block after checking ${MAX_BLOCK_ATTEMPTS} candidates." >&2
  exit 1
}

echo "Using port block ${CHOSEN_BASE} → ${CHOSEN_BASE}+4 (UI ${CHOSEN_BASE}, Docling $((CHOSEN_BASE+1)), Tika $((CHOSEN_BASE+2)), Postgres $((CHOSEN_BASE+3)), Ollama $((CHOSEN_BASE+4)))."

PORT_BLOCK_BASE="$CHOSEN_BASE" PORT_BLOCK_CANDIDATES="$CHOSEN_BASE" "${DEPLOY_SCRIPT}" --name "$DEPLOYMENT_NAME" --port-block "$CHOSEN_BASE"
