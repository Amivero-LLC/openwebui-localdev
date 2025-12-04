#!/usr/bin/env bash
# Prepare and start an isolated Open WebUI deployment.
# - Creates/updates deployments/<name>.env with a dedicated port block
# - Avoids collisions by scanning port blocks (4000, 4100, 4200...) and falling back automatically
# - Uses the deployment name for container, volume, and project naming so multiple stacks can coexist
#
# Usage:
#   scripts/deploy.sh --name myenv [--port-block 4000] [--candidates "4000 4100 4200"] [--env-template .env.example] [--no-start]

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ] || [ "${BASH:-}" = "/bin/sh" ]; then
  exec bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deployments.sh
source "${SCRIPT_DIR}/lib/deployments.sh"

print_usage() {
  cat <<'EOF'
Usage: scripts/deploy.sh --name <deployment>
Options:
  --name, -n         Deployment name (required). Used for env file + compose project.
  --port-block, -p   Preferred starting port (optional; defaults to 4000 or PORT_BLOCK_BASE in env).
  --candidates       Space-separated fallback list of starting ports. Default: "4000 4100 4200 4300 4400".
  --env-template     Source env template to seed new env files. Default: .env.example.
  --reuse            Allow reusing an existing deployments/<name>.env (otherwise prompt to destroy/rebuild or abort).
  --no-start         Write the env file but do not run docker compose up.
  -h, --help         Show this help.
EOF
}

DEPLOYMENT_NAME=""
PORT_BLOCK_OVERRIDE=""
PORT_BLOCK_CANDIDATES=${PORT_BLOCK_CANDIDATES:-"4000 4100 4200 4300 4400"}
ENV_TEMPLATE=".env.example"
AUTO_START="yes"
ALLOW_REUSE="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|-n) DEPLOYMENT_NAME="$2"; shift 2;;
    --port-block|-p) PORT_BLOCK_OVERRIDE="$2"; shift 2;;
    --candidates) PORT_BLOCK_CANDIDATES="$2"; shift 2;;
    --env-template) ENV_TEMPLATE="$2"; shift 2;;
    --reuse) ALLOW_REUSE="yes"; shift 1;;
    --no-start) AUTO_START="no"; shift 1;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 1;;
  esac
done

if [[ -z "$DEPLOYMENT_NAME" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Deployment name (used for env/compose project) [local]: " ans
    DEPLOYMENT_NAME="${ans:-local}"
  else
    echo "Error: --name is required." >&2
    print_usage
    exit 1
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 1
fi

DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-local}"
DEFAULT_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$DEPLOYMENT_NAME}"

PYTHON_BIN="${PYTHON_BIN:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    echo "Error: python3 (or python) is required to write the env file; set PYTHON_BIN if installed elsewhere." >&2
    exit 1
  fi
fi

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ensure_env_dir

TEMPLATE_PATH="${ENV_TEMPLATE}"
[[ -f "$TEMPLATE_PATH" ]] || TEMPLATE_PATH="${REPO_ROOT}/${ENV_TEMPLATE}"
if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "Error: env template '${ENV_TEMPLATE}' not found." >&2
  exit 1
fi

ENV_FILE="${ENV_DIR}/${DEPLOYMENT_NAME}.env"
ENV_EXISTS="no"
if [[ -f "$ENV_FILE" ]]; then
  if [[ "$ALLOW_REUSE" == "yes" ]]; then
    ENV_EXISTS="yes"
  else
    if [[ -t 0 ]]; then
      echo "Environment '${DEPLOYMENT_NAME}' already exists at ${ENV_FILE}."
      read -r -p "Choose: [r]euse, [d]estroy & rebuild, [a]bort [a]: " ans
      case "$ans" in
        r|R) ENV_EXISTS="yes";;
        d|D)
          echo "Destroying existing deployment '${DEPLOYMENT_NAME}' (containers/networks/volumes)..."
          docker compose --project-name "$DEPLOYMENT_NAME" --env-file "$ENV_FILE" -f "${REPO_ROOT}/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true
          rm -f "$ENV_FILE"
          ENV_EXISTS="no"
          ;;
        *) echo "Aborted."; exit 1;;
      esac
    else
      echo "Environment '${DEPLOYMENT_NAME}' already exists at ${ENV_FILE}." >&2
      echo "Use --reuse to start it, choose a different --name, or run interactively to destroy/rebuild." >&2
      exit 1
    fi
  fi
fi

if [[ "$ENV_EXISTS" == "no" ]]; then
  cp "$TEMPLATE_PATH" "$ENV_FILE"
fi

if [[ "$ENV_EXISTS" == "yes" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -PiTCP -sTCP:LISTEN -n -P -t :"$port" >/dev/null 2>&1 && return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -an 2>/dev/null | grep "[.:]${port}[[:space:]]" | grep -i listen >/dev/null 2>&1 && return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Ports}}' 2>/dev/null | tr ',' '\n' | grep -E "[:>]${port}->" >/dev/null 2>&1; then
      return 0
    fi
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
  # also avoid reusing a block that another env has already claimed
  local env_entries
  load_env_entries
  for entry in "${env_entries[@]}"; do
    local name="${entry%%|*}"
    local path="${entry#*|}"
    if [[ "$name" == "$DEPLOYMENT_NAME" ]]; then
      continue
    fi
    local existing_port
    existing_port="$(env_value_from_file "$path" "PORT")"
    if [[ -n "$existing_port" && "$existing_port" == "$base" ]]; then
      return 1
    fi
  done
  return 0
}

uniq_candidates() {
  local seen=""
  local list=("$@")
  local output=()
  for item in "${list[@]}"; do
    if [[ -z "$item" ]]; then
      continue
    fi
    if [[ " $seen " != *" $item "* ]]; then
      seen+=" $item"
      output+=("$item")
    fi
  done
  echo "${output[*]}"
}

candidate_bases=()

if [[ -z "$PORT_BLOCK_OVERRIDE" && -t 0 ]]; then
  read -r -p "Preferred port block start (blank for auto; e.g., 4300): " ans
  if [[ -n "$ans" ]]; then
    PORT_BLOCK_OVERRIDE="$ans"
  fi
fi

if [[ -n "$PORT_BLOCK_OVERRIDE" ]]; then
  candidate_bases+=("$PORT_BLOCK_OVERRIDE")
fi

if [[ -n "${PORT_BLOCK_BASE:-}" ]]; then
  candidate_bases+=("${PORT_BLOCK_BASE}")
fi

read -r -a default_candidates <<<"$PORT_BLOCK_CANDIDATES"
candidate_bases+=("${default_candidates[@]}")

read -r -a candidate_bases <<<"$(uniq_candidates "${candidate_bases[@]}")"

CHOSEN_BASE=""
for base in "${candidate_bases[@]}"; do
  if [[ -z "$base" ]]; then
    continue
  fi
  if ! [[ "$base" =~ ^[0-9]+$ ]]; then
    continue
  fi
  if block_available "$base"; then
    CHOSEN_BASE="$base"
    break
  fi
done

if [[ -z "$CHOSEN_BASE" ]]; then
  echo "Error: no available port blocks found. Checked: ${candidate_bases[*]}" >&2
  exit 1
fi

OPENWEBUI_PORT=$((CHOSEN_BASE + 0))
DOCLING_PORT_VAL=$((CHOSEN_BASE + 1))
TIKA_PORT_VAL=$((CHOSEN_BASE + 2))
POSTGRES_PORT_VAL=$((CHOSEN_BASE + 3))
OLLAMA_PORT_VAL=$((CHOSEN_BASE + 4))

# Try to carry over OpenAI secrets from environment or the repo root .env when creating/updating env files.
ROOT_ENV_FILE="${REPO_ROOT}/.env"
OPENAI_API_KEY_VALUE="${OPENAI_API_KEY:-}"
OPENAI_API_BASE_URLS_VALUE="${OPENAI_API_BASE_URLS:-}"
OPENAI_MODEL_VALUE="${OPENAI_MODEL:-}"
if [[ -z "$OPENAI_API_KEY_VALUE" && -f "$ROOT_ENV_FILE" ]]; then
  OPENAI_API_KEY_VALUE="$(env_value_from_file "$ROOT_ENV_FILE" "OPENAI_API_KEY")"
fi
if [[ -z "$OPENAI_API_BASE_URLS_VALUE" && -f "$ROOT_ENV_FILE" ]]; then
  OPENAI_API_BASE_URLS_VALUE="$(env_value_from_file "$ROOT_ENV_FILE" "OPENAI_API_BASE_URLS")"
fi
if [[ -z "$OPENAI_MODEL_VALUE" && -f "$ROOT_ENV_FILE" ]]; then
  OPENAI_MODEL_VALUE="$(env_value_from_file "$ROOT_ENV_FILE" "OPENAI_MODEL")"
fi

DATA_ROOT_REL="data/${DEPLOYMENT_NAME}"
OPENWEBUI_DATA_DIR_VAL="./${DATA_ROOT_REL}/open-webui"
POSTGRES_DATA_DIR_VAL="./${DATA_ROOT_REL}/postgres"

updates_json=$(cat <<EOF
{
  "PORT_BLOCK_BASE": "$CHOSEN_BASE",
  "PORT": "$OPENWEBUI_PORT",
  "DOCLING_PORT": "$DOCLING_PORT_VAL",
  "TIKA_PORT": "$TIKA_PORT_VAL",
  "POSTGRES_PORT": "$POSTGRES_PORT_VAL",
  "OLLAMA_PORT": "$OLLAMA_PORT_VAL",
  "OLLAMA_BASE_URL": "http://ollama:11434",
  "OLLAMA_BASE_URL_HOST": "http://localhost:${OLLAMA_PORT_VAL}",
  "TIKA_SERVER_URL": "http://tika:9998",
  "PGHOST": "localhost",
  "PGPORT": "$POSTGRES_PORT_VAL",
  "PGVECTOR_DB_URL": "postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/${POSTGRES_DB:-openwebui}",
  "DATABASE_URL": "postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/${POSTGRES_DB:-openwebui}",
  "PGVECTOR_DB_URL_HOST": "postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@localhost:${POSTGRES_PORT_VAL}/${POSTGRES_DB:-openwebui}",
  "DATABASE_URL_HOST": "postgresql://postgres:${POSTGRES_PASSWORD:-postgres}@localhost:${POSTGRES_PORT_VAL}/${POSTGRES_DB:-openwebui}",
  "CORS_ALLOW_ORIGIN": "http://localhost:${OPENWEBUI_PORT}",
  "DEPLOYMENT_NAME": "${DEPLOYMENT_NAME}",
  "COMPOSE_PROJECT_NAME": "${DEFAULT_PROJECT_NAME}",
  "OPENWEBUI_DATA_DIR": "${OPENWEBUI_DATA_DIR_VAL}",
  "POSTGRES_DATA_DIR": "${POSTGRES_DATA_DIR_VAL}"
}
EOF
)

OPENAI_API_KEY_VALUE="$OPENAI_API_KEY_VALUE" OPENAI_API_BASE_URLS_VALUE="$OPENAI_API_BASE_URLS_VALUE" OPENAI_MODEL_VALUE="$OPENAI_MODEL_VALUE" \
$PYTHON_BIN - "$ENV_FILE" "$updates_json" <<'PY'
import json, os, sys
from pathlib import Path

path = Path(sys.argv[1])
updates = json.loads(sys.argv[2])

extras = {
    "OPENAI_API_KEY": os.environ.get("OPENAI_API_KEY_VALUE") or "",
    "OPENAI_API_BASE_URLS": os.environ.get("OPENAI_API_BASE_URLS_VALUE") or "",
    "OPENAI_MODEL": os.environ.get("OPENAI_MODEL_VALUE") or "",
}
for key, val in extras.items():
    if val:
        updates[key] = val

lines = path.read_text().splitlines()
seen = set()

for idx, line in enumerate(lines):
    if line.strip().startswith("#") or "=" not in line:
        continue
    key, _ = line.split("=", 1)
    if key in updates:
        lines[idx] = f"{key}={updates[key]}"
        seen.add(key)

for key, value in updates.items():
    if key not in seen:
        lines.append(f"{key}={value}")

path.write_text("\n".join(lines) + ("\n" if lines else ""))
PY

echo "Deployment env ready: ${ENV_FILE}"
echo "  Deployment name: ${DEPLOYMENT_NAME}"
echo "  Port block: ${CHOSEN_BASE} → ${CHOSEN_BASE}+4 (UI ${OPENWEBUI_PORT}, Docling ${DOCLING_PORT_VAL}, Tika ${TIKA_PORT_VAL}, Postgres ${POSTGRES_PORT_VAL}, Ollama ${OLLAMA_PORT_VAL})"

if [[ "$AUTO_START" == "no" ]]; then
  echo "Skipping docker compose up (per --no-start)."
  exit 0
fi

echo "Starting deployment..."
docker compose --project-name "$DEPLOYMENT_NAME" --env-file "$ENV_FILE" -f "${REPO_ROOT}/docker-compose.yml" up -d

record_current_env "$DEPLOYMENT_NAME"

echo
echo "✔ '${DEPLOYMENT_NAME}' is running."
echo "  - Open WebUI: http://localhost:${OPENWEBUI_PORT}"
echo "  - Docling UI: http://localhost:${DOCLING_PORT_VAL} (if enabled)"
echo "  - Apache Tika: http://localhost:${TIKA_PORT_VAL}/tika"
echo "  - PostgreSQL:  host=localhost port=${POSTGRES_PORT_VAL} db=${POSTGRES_DB:-openwebui}"
echo "  - Ollama API:  http://localhost:${OLLAMA_PORT_VAL}"
echo
docker compose --project-name "$DEPLOYMENT_NAME" --env-file "$ENV_FILE" -f "${REPO_ROOT}/docker-compose.yml" ps
