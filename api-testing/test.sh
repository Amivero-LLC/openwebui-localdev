#!/usr/bin/env bash
set -euo pipefail

# Re-exec with bash if not already running under bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

# Load environment variables from api-testing/.env so this script is isolated
SCRIPT_DIR="$(dirname "$0")"
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  echo "Create it by copying: $SCRIPT_DIR/.env.example -> $ENV_FILE" >&2
  exit 1
fi
# shellcheck source=/dev/null
set -a
. "$ENV_FILE"
set +a

# Sanity logs for required vars
log() {
  if [ "${DEBUG:-0}" = "1" ]; then
    echo "[api-testing] $*" >&2
  fi
}

# Color-aware logging if stderr is a TTY
_RED=""; _DIM=""; _RESET=""
if [ -t 2 ]; then
  _RED="\033[31m"; _DIM="\033[2m"; _RESET="\033[0m"
fi

DEBUG=${DEBUG:-0}
trace(){ if [ "$DEBUG" = "2" ]; then set -x; fi; }

debug_dump_env(){
  log "ENV_FILE=$ENV_FILE"
  log "BASE_URL=${BASE_URL:-}"
  log "MODEL=$MODEL"
  log "MAX_TOKENS=$MAX_TOKENS TEMPERATURE=$TEMPERATURE"
}

log "Flags: --stream (SSE live tokens), --raw (print raw JSON)"

# Defaults
MAX_TOKENS="${MAX_TOKENS:-256}"
TEMPERATURE="${TEMPERATURE:-0.2}"
MODEL="${OPENAI_MODEL:-${BEDROCK_BASE_MODEL_ID:-us.anthropic.claude-3-5-haiku-20241022-v1:0}}"

# Connection selection
# Choose with: --conn openwebui|bag|aws|openai or env API_TEST_TARGET
API_TEST_TARGET="${API_TEST_TARGET:-}"

# Args: <prompt> [--stream] [--raw]
STREAM_FLAG=0
RAW_FLAG=0

# Parse flags (they can appear before or after the prompt)
USER_MESSAGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stream) STREAM_FLAG=1; shift ;;
    --raw)    RAW_FLAG=1; shift ;;
    --conn)
      API_TEST_TARGET="${2:-}"; shift 2 ;;
    --conn=*)
      API_TEST_TARGET="${1#--conn=}"; shift ;;
    --openwebui) API_TEST_TARGET="openwebui"; shift ;;
    --bag)       API_TEST_TARGET="bag"; shift ;;
    --aws)       API_TEST_TARGET="aws"; shift ;;
    --openai)    API_TEST_TARGET="openai"; shift ;;
    *)
      if [ -z "$USER_MESSAGE" ]; then
        USER_MESSAGE="$1"
      else
        USER_MESSAGE="$USER_MESSAGE $1"
      fi
      shift ;;
  esac
done

if [ -z "$USER_MESSAGE" ]; then
  if [ -t 0 ]; then
    read -rp "Enter prompt text (leave empty to test connectivity): " USER_MESSAGE || true
  fi
  # Allow empty/null prompt to test connectivity or system behavior.
  if [ -z "${USER_MESSAGE:-}" ]; then
    log "Empty prompt provided; sending minimal request."
  fi
fi

# Normalize numeric connection values if provided via flags/env
case "${API_TEST_TARGET:-}" in
  1) API_TEST_TARGET="openwebui" ;;
  2) API_TEST_TARGET="bag" ;;
  3) API_TEST_TARGET="aws" ;;
  4) API_TEST_TARGET="openai" ;;
esac

# Determine or prompt for target connection
if [ -z "$API_TEST_TARGET" ]; then
  has_bag=0; has_openwebui=0; has_openai=0
  [ -n "${BAG_BASE_URL:-}" ] && [ -n "${BAG_API_KEY:-}" ] && has_bag=1
  [ -n "${OPENWEBUI_BASE_URL:-}" ] && [ -n "${OPENWEBUI_API_KEY:-}" ] && has_openwebui=1
  [ -n "${OPENAI_DIRECT_BASE_URL:-}" ] && [ -n "${OPENAI_DIRECT_API_KEY:-}" ] && has_openai=1

  DEFAULT_TARGET=""
  if [ $has_bag -eq 1 ]; then
    DEFAULT_TARGET="bag"
  elif [ $has_openwebui -eq 1 ]; then
    DEFAULT_TARGET="openwebui"
  elif [ $has_openai -eq 1 ]; then
    DEFAULT_TARGET="openai"
  else
    DEFAULT_TARGET="aws"
  fi

  if [ -t 0 ]; then
    # Map default target to numeric default
    case "$DEFAULT_TARGET" in
      openwebui) DEFAULT_NUM=1 ;;
      bag)       DEFAULT_NUM=2 ;;
      aws)       DEFAULT_NUM=3 ;;
      openai)    DEFAULT_NUM=4 ;;
      *)         DEFAULT_NUM=2 ;;
    esac
    while :; do
      echo "Select connection to test:"
      echo "  1) Open WebUI"
      echo "  2) Bedrock Access Gateway"
      echo "  3) AWS Bedrock Direct (placeholder)"
      echo "  4) OpenAI Direct"
      read -rp "Enter choice [1-4] (default: ${DEFAULT_NUM}): " sel || true
      sel=${sel:-$DEFAULT_NUM}
      case "$sel" in
        1) API_TEST_TARGET="openwebui"; break ;;
        2) API_TEST_TARGET="bag"; break ;;
        3) API_TEST_TARGET="aws"; break ;;
        4) API_TEST_TARGET="openai"; break ;;
        *) echo "Invalid choice: $sel. Please enter 1, 2, 3, or 4." >&2 ;;
      esac
    done
  else
    API_TEST_TARGET="$DEFAULT_TARGET"
  fi
fi

# Resolve base URL and auth per target
case "$API_TEST_TARGET" in
  openwebui)
    : "${OPENWEBUI_BASE_URL:?Need OPENWEBUI_BASE_URL in api-testing/.env for openwebui}"
    : "${OPENWEBUI_API_KEY:?Need OPENWEBUI_API_KEY in api-testing/.env for openwebui}"
    BASE_URL="$OPENWEBUI_BASE_URL"; API_KEY="$OPENWEBUI_API_KEY"; MODEL="${OPENWEBUI_MODEL:-${BEDROCK_BASE_MODEL_ID:-$MODEL}}" ;;
  bag)
    : "${BAG_BASE_URL:?Need BAG_BASE_URL in api-testing/.env for bag}"
    : "${BAG_API_KEY:?Need BAG_API_KEY in api-testing/.env for bag}"
    BASE_URL="$BAG_BASE_URL"; API_KEY="$BAG_API_KEY"; MODEL="${BAG_MODEL:-${BEDROCK_BASE_MODEL_ID:-$MODEL}}" ;;
  aws)
    echo "AWS Bedrock (Direct): Placeholder. Not implemented yet." >&2
    echo "Add SigV4 signing and Bedrock Invoke/Converse API integration." >&2
    exit 2 ;;
  openai)
    : "${OPENAI_DIRECT_BASE_URL:?Need OPENAI_DIRECT_BASE_URL in api-testing/.env for openai}"
    : "${OPENAI_DIRECT_API_KEY:?Need OPENAI_DIRECT_API_KEY in api-testing/.env for openai}"
    BASE_URL="$OPENAI_DIRECT_BASE_URL"; API_KEY="$OPENAI_DIRECT_API_KEY"; MODEL="${OPENAI_DIRECT_MODEL:-${MODEL:-gpt-4o-mini}}" ;;
  *)
    echo "Unknown --conn target: $API_TEST_TARGET (expected openwebui|bag|aws|openai)" >&2
    exit 1 ;;
esac

URL="${BASE_URL%/}/chat/completions"
log "Resolved URL: $URL"
trace

# Build JSON payload (avoid read -d '' which exits under set -e)
if command -v jq >/dev/null 2>&1; then
  STREAM_BOOL=$( [ $STREAM_FLAG -eq 1 ] && echo true || echo false )
  PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --argjson max_tokens "$MAX_TOKENS" \
    --argjson temperature "$TEMPERATURE" \
    --argjson stream "$STREAM_BOOL" \
    --arg user "$USER_MESSAGE" \
    '{
       model: $model,
       max_tokens: $max_tokens,
       temperature: $temperature,
       stream: $stream,
       messages: [
         {role:"system", content:"You are a helpful assistant."},
         {role:"user", content:$user}
       ]
     }')
else
  # Fallback without jq: minimally escape quotes and backslashes
  ESC_USER_MESSAGE=${USER_MESSAGE//\\/\\\\}
  ESC_USER_MESSAGE=${ESC_USER_MESSAGE//\"/\\\"}
  PAYLOAD=$(cat <<JSON
{
  "model": "$MODEL",
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE,
  "stream": $( [ $STREAM_FLAG -eq 1 ] && echo true || echo false ),
  "messages": [
    { "role": "system", "content": "You are a helpful assistant." },
    { "role": "user", "content": "$ESC_USER_MESSAGE" }
  ]
}
JSON
)
fi

if [ "$DEBUG" != "0" ]; then
  log "Request payload:"; echo "$PAYLOAD" | sed 's/\(Authorization: Bearer \)[^\"]\+/\1***REDACTED***/' >&2
fi

# Robust curl request/response handling
debug_dump_env
log "Target: $API_TEST_TARGET"
log "POST $URL"
log "Model: $MODEL | Max tokens: $MAX_TOKENS | Temp: $TEMPERATURE"

START_TS=$(date +%s)

if [ $STREAM_FLAG -eq 1 ]; then
  log "Streaming mode enabled (SSE)"
  # Preflight request to surface HTTP and JSON errors before streaming
  PF_RESP_FILE=$(mktemp)
  PF_HTTP=$(curl -sS -w "%{http_code}" -o "$PF_RESP_FILE" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -X POST "$URL" \
    -d "$PAYLOAD") || PF_RC=$?
  PF_RC=${PF_RC:-0}
  if [ $PF_RC -ne 0 ]; then
    echo -e "${_RED}Curl failed (rc=$PF_RC).${_RESET} Check base URL, DNS/TLS, and gateway health." >&2
    [ -s "$PF_RESP_FILE" ] && cat "$PF_RESP_FILE" >&2
    rm -f "$PF_RESP_FILE"
    exit 1
  fi
  if ! printf '%s' "$PF_HTTP" | grep -q '^2'; then
    echo "HTTP $PF_HTTP error. Full body:" >&2
    cat "$PF_RESP_FILE" >&2
    rm -f "$PF_RESP_FILE"
    exit 1
  fi
  rm -f "$PF_RESP_FILE"

  # Proceed with actual streaming request
  curl -sS -N \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -X POST "$URL" \
    -d "$PAYLOAD" |
  while IFS= read -r line; do
    case "$line" in
      data:*)
        data="${line#data: }"
        if [ "$data" = "[DONE]" ]; then echo; break; fi
        chunk=$(printf '%s' "$data" | jq -r 'try .choices[0].delta.content // ""' 2>/dev/null || echo "")
        [ -n "$chunk" ] && printf '%s' "$chunk"
        if [ "$DEBUG" = "1" ]; then
          log "SSE line: ${_DIM}${line}${_RESET}"
        fi
        ;;
    esac
  done
  END_TS=$(date +%s); log "Completed in $((END_TS-START_TS))s"
  exit 0
fi

# Non-streaming path with detailed timing metrics
RESP_FILE=$(mktemp); META_FILE=$(mktemp)
CURL_FMT='{\n  "http_code": "%{http_code}",\n  "remote_ip": "%{remote_ip}",\n  "ssl_verify_result": "%{ssl_verify_result}",\n  "namelookup_time": "%{time_namelookup}",\n  "connect_time": "%{time_connect}",\n  "appconnect_time": "%{time_appconnect}",\n  "pretransfer_time": "%{time_pretransfer}",\n  "starttransfer_time": "%{time_starttransfer}",\n  "redirect_time": "%{time_redirect}",\n  "total_time": "%{time_total}",\n  "size_upload": "%{size_upload}",\n  "size_download": "%{size_download}",\n  "speed_download": "%{speed_download}",\n  "speed_upload": "%{speed_upload}"\n}'
HTTP_STATUS=$(curl -sS -w "%{http_code}" -o "$RESP_FILE" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -X POST "$URL" \
  -d "$PAYLOAD")
# Also collect metrics in a separate call so we preserve http_code in variable above
curl -sS -o /dev/null -w "$CURL_FMT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -X POST "$URL" \
  -d "$PAYLOAD" > "$META_FILE" || true

CURL_RC=$?
if [ $CURL_RC -ne 0 ]; then
  echo -e "${_RED}Curl failed (rc=$CURL_RC).${_RESET} Check base URL, DNS/TLS, and gateway health." >&2
  [ -s "$RESP_FILE" ] && cat "$RESP_FILE" >&2
  rm -f "$RESP_FILE" "$META_FILE"
  exit 1
fi

BODY=$(cat "$RESP_FILE"); METRICS=$(cat "$META_FILE")
rm -f "$RESP_FILE" "$META_FILE"

log "Metrics: $METRICS"

case "$HTTP_STATUS" in
  2**) ;;
  *)
    echo "HTTP $HTTP_STATUS error. Full body:" >&2
    echo "$BODY" >&2
    exit 1
    ;;
esac

if [ $RAW_FLAG -eq 1 ]; then
  echo "$BODY"
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  echo "$BODY" | jq -r 'try .choices[0].message.content // .error // .'
else
  echo "$BODY"
fi
END_TS=$(date +%s); log "Completed in $((END_TS-START_TS))s"
