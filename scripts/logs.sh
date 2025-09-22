#!/usr/bin/env bash
# Tail logs for the stack.
# - Shows logs from all services (Open WebUI, PostgreSQL, Tika, Ollama, Docling)
# - Adds basic ANSI color highlighting when a TTY is detected based on log level keywords
# - Follows output until interrupted (Ctrl+C)
#
# Usage: scripts/logs.sh [service...]
#   If service names are provided, follows only those logs (e.g. open-webui postgres).

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

LOG_ARGS=(-f)
if [ "$#" -gt 0 ]; then
  LOG_ARGS+=("$@")
fi

stream_logs() {
  docker compose logs --no-color "${LOG_ARGS[@]}"
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
