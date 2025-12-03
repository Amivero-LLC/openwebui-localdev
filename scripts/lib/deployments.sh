#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers for selecting deployments/environments across lifecycle scripts.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_DIR="${REPO_ROOT}/deployments"
CURRENT_FILE="${ENV_DIR}/.current"

ensure_env_dir() {
  mkdir -p "$ENV_DIR"
}

list_env_entries() {
  ensure_env_dir
  if [[ -f "${REPO_ROOT}/.env" ]]; then
    echo "default|${REPO_ROOT}/.env"
  fi

  shopt -s nullglob
  for file in "${ENV_DIR}"/*.env; do
    [[ -f "$file" ]] || continue
    local name
    name="$(basename "$file" ".env")"
    echo "${name}|${file}"
  done
  shopt -u nullglob
}

env_value_from_file() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || { echo ""; return; }
  (
    set -a
    # shellcheck disable=SC1090
    source "$file" >/dev/null 2>&1 || true
    set +a
    # shellcheck disable=SC1083
    eval "printf '%s' \"\${${key}:-}\""
  )
}

current_env_name() {
  local names=("$@")
  if [[ -f "$CURRENT_FILE" ]]; then
    local stored
    read -r stored <"$CURRENT_FILE"
    for name in "${names[@]}"; do
      if [[ "$name" == "$stored" ]]; then
        echo "$name"
        return
      fi
    done
  fi
  echo "${names[0]}"
}

record_current_env() {
  ensure_env_dir
  echo "$1" >"$CURRENT_FILE"
}

load_env_entries() {
  env_entries=()
  local output
  output="$(list_env_entries)"
  while IFS= read -r line; do
    [[ -n "$line" ]] && env_entries+=("$line")
  done <<<"$output"
}

select_environment_for_action() {
  local action="$1"; shift || true
  local requested="" use_current="no"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env|-e) requested="$2"; shift 2;;
      --current|--no-select) use_current="yes"; shift 1;;
      *) shift 1;; # ignore unknowns (handled by caller)
    esac
  done

  load_env_entries
  if [[ ${#env_entries[@]} -eq 0 ]]; then
    echo "No environments found. Create one with scripts/deploy.sh --name <id> or copy .env.example to .env." >&2
    exit 1
  fi

  local names=() paths=()
  for entry in "${env_entries[@]}"; do
    names+=("${entry%%|*}")
    paths+=("${entry#*|}")
  done

  local default_name
  default_name="$(current_env_name "${names[@]}")"
  local default_idx=0
  for i in "${!names[@]}"; do
    if [[ "${names[$i]}" == "$default_name" ]]; then
      default_idx="$i"
      break
    fi
  done

  local chosen_idx=""

  if [[ -n "$requested" ]]; then
    for i in "${!names[@]}"; do
      if [[ "${names[$i]}" == "$requested" ]]; then
        chosen_idx="$i"
        break
      fi
    done
    if [[ -z "$chosen_idx" ]]; then
      echo "Environment '${requested}' not found. Available: ${names[*]}" >&2
      exit 1
    fi
  elif [[ "$use_current" == "yes" || ! -t 0 ]]; then
    chosen_idx="$default_idx"
  else
    echo "Select an environment to ${action}:"
    for i in "${!names[@]}"; do
      local marker=""
      if [[ "${names[$i]}" == "$default_name" ]]; then
        marker=" (current)"
      fi
      printf "  %2d) %s%s\n" "$((i + 1))" "${names[$i]}" "$marker"
    done
    read -r -p "Choice [$((default_idx + 1))]: " answer
    if [[ -z "$answer" ]]; then
      chosen_idx="$default_idx"
    elif [[ "$answer" =~ ^[0-9]+$ ]]; then
      answer=$((answer - 1))
      if (( answer < 0 || answer >= ${#names[@]} )); then
        echo "Invalid selection." >&2
        exit 1
      fi
      chosen_idx="$answer"
    else
      for i in "${!names[@]}"; do
        if [[ "${names[$i]}" == "$answer" ]]; then
          chosen_idx="$i"
          break
        fi
      done
      if [[ -z "$chosen_idx" ]]; then
        echo "Invalid selection." >&2
        exit 1
      fi
    fi
  fi

  SELECTED_ENV_NAME="${names[$chosen_idx]}"
  SELECTED_ENV_FILE="${paths[$chosen_idx]}"
  SELECTED_PROJECT_NAME="$(env_value_from_file "$SELECTED_ENV_FILE" "COMPOSE_PROJECT_NAME")"
  if [[ -z "$SELECTED_PROJECT_NAME" ]]; then
    SELECTED_PROJECT_NAME="$(env_value_from_file "$SELECTED_ENV_FILE" "DEPLOYMENT_NAME")"
  fi
  if [[ -z "$SELECTED_PROJECT_NAME" ]]; then
    SELECTED_PROJECT_NAME="$SELECTED_ENV_NAME"
  fi
  SELECTED_PORT="$(env_value_from_file "$SELECTED_ENV_FILE" "PORT")"
  SELECTED_DOCLING_PORT="$(env_value_from_file "$SELECTED_ENV_FILE" "DOCLING_PORT")"
  SELECTED_TIKA_PORT="$(env_value_from_file "$SELECTED_ENV_FILE" "TIKA_PORT")"
  SELECTED_POSTGRES_PORT="$(env_value_from_file "$SELECTED_ENV_FILE" "POSTGRES_PORT")"
  SELECTED_OLLAMA_PORT="$(env_value_from_file "$SELECTED_ENV_FILE" "OLLAMA_PORT")"

  COMPOSE_ARGS=(-f "${REPO_ROOT}/docker-compose.yml" --project-name "$SELECTED_PROJECT_NAME")
  if [[ -n "$SELECTED_ENV_FILE" ]]; then
    COMPOSE_ARGS+=(--env-file "$SELECTED_ENV_FILE")
  fi
}
