#!/usr/bin/env bash
# Rebuild (delete and recreate) the full AmiChat environment.
# - Stops containers for Open WebUI, PostgreSQL, Tika, Ollama, and Docling
# - Removes networks and declared volumes (data loss!)
# - PRUNES unused Docker resources system-wide (containers, images, networks,
#   and volumes) via `docker system prune -a --volumes -f`
# - Pulls latest images (respecting .env IMAGE/TAG, DOCLING_IMAGE/TAG, etc.)
# - Recreates containers fresh
#
# Usage:
#   scripts/rebuild.sh [--yes] [--env <name>] [--current]
#     --yes      Proceed without interactive confirmation (DESTRUCTIVE)
#     --env/-e   Target a specific environment
#     --current  Skip selection and rebuild the current environment

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
Usage: scripts/rebuild.sh [--yes] [--env <name>] [--current]
  --yes         Skip destructive confirmation
  --env/-e      Target a specific environment
  --current     Skip selection and rebuild the current environment
  SERVICE=...   (env) limit rebuild to a single compose service; defaults to prompt
EOF
}

CONFIRM="ask"
SELECTION_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) CONFIRM="yes"; shift 1;;
    --env|-e) SELECTION_ARGS+=("$1" "$2"); shift 2;;
    --current|--no-select) SELECTION_ARGS+=("$1"); shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

select_environment_for_action "rebuild" "${SELECTION_ARGS[@]}"

VOLUME_NAME_VALUE="$(env_value_from_file "$SELECTED_ENV_FILE" "VOLUME_NAME")"
WARN_VOLUMES="${VOLUME_NAME_VALUE:-open-webui}, docling-cache, ollama-models, postgres-data"

if ! SERVICES=$(docker compose "${COMPOSE_ARGS[@]}" config --services); then
  echo "Error: unable to discover services from docker-compose.yml" >&2
  exit 1
fi

SERVICE_LIST=()
while IFS= read -r svc; do
  [[ -n "$svc" ]] && SERVICE_LIST+=("$svc")
done <<EOF
$SERVICES
EOF

if [[ ${#SERVICE_LIST[@]} -eq 0 ]]; then
  echo "Error: unable to discover services from docker-compose.yml" >&2
  exit 1
fi

warn() { printf "\033[33m%s\033[0m\n" "$*"; }

SERVICE_CHOICE="${SERVICE:-}"

select_all() {
  SELECTED_MODE="all"
  TARGET_SERVICE=""
}

select_service() {
  SELECTED_MODE="service"
  TARGET_SERVICE="$1"
}

if [[ -n "$SERVICE_CHOICE" ]]; then
  if [[ "$SERVICE_CHOICE" == "all" ]]; then
    select_all
  else
    for svc in "${SERVICE_LIST[@]}"; do
      if [[ "$svc" == "$SERVICE_CHOICE" ]]; then
        select_service "$svc"
        break
      fi
    done
    if [[ -z "${TARGET_SERVICE:-}" ]]; then
      echo "Error: SERVICE='$SERVICE_CHOICE' does not match any compose service" >&2
      echo "Known services: ${SERVICE_LIST[*]}" >&2
      exit 1
    fi
  fi
else
  if [[ ! -t 0 ]]; then
    echo "Error: interactive service selection required (stdin is not a TTY)." >&2
    echo "Provide SERVICE=all or SERVICE=<service> when running non-interactively." >&2
    exit 1
  fi

  echo "Select a service to rebuild:" 
  for idx in "${!SERVICE_LIST[@]}"; do
    printf "  %2d) %s\n" "$((idx + 1))" "${SERVICE_LIST[$idx]}"
  done
  echo "  a) All services"

  read -r -p "Choice [a]: " answer

  if [[ -z "$answer" || "$answer" =~ ^[aA]$ ]]; then
    select_all
  elif [[ "$answer" =~ ^[0-9]+$ ]]; then
    idx=$((answer - 1))
    if (( idx < 0 || idx >= ${#SERVICE_LIST[@]} )); then
      echo "Invalid selection." >&2
      exit 1
    fi
    select_service "${SERVICE_LIST[$idx]}"
  else
    for svc in "${SERVICE_LIST[@]}"; do
      if [[ "$svc" == "$answer" ]]; then
        select_service "$svc"
        break
      fi
    done
    if [[ -z "${TARGET_SERVICE:-}" ]]; then
      echo "Invalid selection." >&2
      exit 1
    fi
  fi
fi

if [[ "$SELECTED_MODE" == "all" ]]; then
  warn "This will DELETE volumes and all application data for this stack."
  warn "Volumes to be removed: ${WARN_VOLUMES}"
  warn "This will also RUN 'docker system prune -a --volumes -f' which removes unused containers, images, networks, and volumes across your system."

  if [[ "$CONFIRM" == "ask" ]]; then
    if [ -t 0 ]; then
      read -r -p "Proceed with destructive rebuild? [y/N] " ans
      case "$ans" in
        y|Y|yes|YES) : ;;
        *) echo "Aborted."; exit 1;;
      esac
    else
      echo "Non-interactive shell. Re-run with --yes to confirm destructive rebuild." >&2
      exit 1
    fi
  fi

  echo "Stopping and removing containers, networks, and volumes..."
  docker compose "${COMPOSE_ARGS[@]}" down -v --remove-orphans

  # Attempt to remove the named data volume explicitly (ignore errors)
  docker volume rm "${VOLUME_NAME_VALUE:-open-webui}" >/dev/null 2>&1 || true

  echo "Pruning unused Docker resources (containers, images, networks, volumes)..."
  docker system prune -a --volumes -f

  echo "Pulling latest images..."
  docker compose "${COMPOSE_ARGS[@]}" pull

  echo "Recreating containers..."
  docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate

  echo
  echo "✔ Rebuild complete. Endpoints:"
  echo "  - Open WebUI: http://localhost:${SELECTED_PORT:-4000}"
  echo "  - Docling UI: http://localhost:${SELECTED_DOCLING_PORT:-5001} (if enabled)"
  echo "  - Apache Tika: http://localhost:${SELECTED_TIKA_PORT:-9998}/tika"
  echo "  - PostgreSQL:  host=localhost port=${SELECTED_POSTGRES_PORT:-5432} db=${POSTGRES_DB:-openwebui}"
  echo "  - Ollama API:  http://localhost:${SELECTED_OLLAMA_PORT:-11434} (or ollama:11434 inside compose)"
  echo
  docker compose "${COMPOSE_ARGS[@]}" ps
else
  echo "Rebuilding service '${TARGET_SERVICE}'..."
  docker compose "${COMPOSE_ARGS[@]}" stop "$TARGET_SERVICE" >/dev/null 2>&1 || true
  docker compose "${COMPOSE_ARGS[@]}" rm -f "$TARGET_SERVICE" >/dev/null 2>&1 || true

  echo "Pulling latest image for '${TARGET_SERVICE}'..."
  docker compose "${COMPOSE_ARGS[@]}" pull "$TARGET_SERVICE"

  echo "Recreating '${TARGET_SERVICE}' container..."
  docker compose "${COMPOSE_ARGS[@]}" up -d --force-recreate --no-deps "$TARGET_SERVICE"

  echo
  docker compose "${COMPOSE_ARGS[@]}" ps "$TARGET_SERVICE"
fi

record_current_env "$SELECTED_ENV_NAME"
