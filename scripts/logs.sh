#!/usr/bin/env bash
# Tail logs for the stack.
# - Shows logs from all services (Open WebUI, PostgreSQL, Tika, Ollama, Docling)
# - Adds basic ANSI color highlighting when a TTY is detected based on log level keywords
# - Follows output until interrupted (Ctrl+C)
#
# Usage: scripts/logs.sh [--env <name>] [--current] [service...]
#   If service names are provided, follows only those logs (e.g. open-webui postgres).

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
Usage: scripts/logs.sh [--env <name>] [--current] [service...]
  --env/-e     Target a specific environment
  --current    Skip selection and stream logs for the current environment
  service...   Optional compose services to filter (e.g., open-webui postgres)
EOF
}

SELECTION_ARGS=()
SERVICE_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env|-e) SELECTION_ARGS+=("$1" "$2"); shift 2;;
    --current|--no-select) SELECTION_ARGS+=("$1"); shift 1;;
    -h|--help) usage; exit 0;;
    *) SERVICE_ARGS+=("$1"); shift 1;;
  esac
done

select_environment_for_action "stream logs for" "${SELECTION_ARGS[@]}"

LOG_ARGS=(-f)
if [ ${#SERVICE_ARGS[@]} -gt 0 ]; then
  LOG_ARGS+=("${SERVICE_ARGS[@]}")
fi

stream_logs() {
  docker compose "${COMPOSE_ARGS[@]}" logs --no-color "${LOG_ARGS[@]}"
}

if [ -t 1 ]; then
  AWK_BIN="awk"
  if command -v gawk >/dev/null 2>&1; then
    AWK_BIN="gawk"
  fi
  stream_logs | "$AWK_BIN" '
    BEGIN {
      esc = sprintf("\033");
      red = esc "[31m"; yellow = esc "[33m"; blue = esc "[34m"; cyan = esc "[36m"; magenta = esc "[35m"; reset = esc "[0m";
      IGNORECASE = 1;
    }
    {
      line = $0
      gsub(/FATAL/, red "&" reset, line)
      gsub(/ERROR/, red "&" reset, line)
      gsub(/WARN(ING)?/, yellow "&" reset, line)
      gsub(/INFO/, cyan "&" reset, line)
      gsub(/DEBUG/, magenta "&" reset, line)
      gsub(/TRACE/, blue "&" reset, line)
      print line
    }
  '
else
  stream_logs
fi
