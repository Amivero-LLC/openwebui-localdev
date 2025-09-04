#!/usr/bin/env bash
set -euo pipefail

# Ensure we are running under bash even if invoked as `sh`
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

# Download a Hugging Face repo into the Hugging Face CACHE layout under ./hf-cache/hub.
# Usage: scripts/hf-download.sh <repo_id> [--revision <rev>] [--include <pattern>] [--exclude <pattern>]

REPO_ID=${1:-}
shift || true

if [[ -z "$REPO_ID" ]]; then
  echo "Usage: scripts/hf-download.sh <repo_id> [--revision <rev>] [--include <pattern>] [--exclude <pattern>]" >&2
  exit 1
fi

mkdir -p hf-cache

if command -v huggingface-cli >/dev/null 2>&1; then
  # Prefer CLI and populate HF cache at ./hf-cache (no --local-dir)
  HF_HOME="$(pwd)/hf-cache" TRANSFORMERS_CACHE="$(pwd)/hf-cache/hub" \
    huggingface-cli download "$REPO_ID" "$@"
  echo "✔ Download complete. Mounted in container at /opt/app-root/src/.cache/huggingface"
  exit 0
fi

# Fallback to local Python if available
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

if [[ -n "$PYTHON_BIN" ]]; then
  echo "huggingface-cli not found. Trying $PYTHON_BIN with huggingface_hub..." >&2
  # Ensure huggingface_hub is available; try to install if missing
  if ! $PYTHON_BIN -c 'import huggingface_hub' >/dev/null 2>&1; then
    echo "Installing huggingface_hub into $PYTHON_BIN (pip) ..." >&2
    $PYTHON_BIN -m pip install --quiet 'huggingface_hub' || true
  fi
  if $PYTHON_BIN -c 'import huggingface_hub' >/dev/null 2>&1; then
    HF_HOME="$(pwd)/hf-cache" TRANSFORMERS_CACHE="$(pwd)/hf-cache/hub" \
      $PYTHON_BIN - "$REPO_ID" "$@" <<'PY'
import os, sys
from huggingface_hub import snapshot_download

repo_id = sys.argv[1]
os.environ.setdefault('HF_HOME', os.path.abspath('hf-cache'))
os.environ.setdefault('TRANSFORMERS_CACHE', os.path.abspath('hf-cache/hub'))

revision = None
include = None
exclude = None
# Simple arg parse for --revision/--include/--exclude
args = sys.argv[2:]
for i in range(len(args)):
    if args[i] == '--revision' and i + 1 < len(args):
        revision = args[i+1]
    if args[i] == '--include' and i + 1 < len(args):
        include = args[i+1]
    if args[i] == '--exclude' and i + 1 < len(args):
        exclude = args[i+1]

snapshot_download(
    repo_id=repo_id,
    revision=revision,
    local_dir=None,
    local_dir_use_symlinks=False,
    allow_patterns=[include] if include else None,
    ignore_patterns=[exclude] if exclude else None,
)
print(f"Cached {repo_id} under {os.environ['HF_HOME']}")
PY
    echo "✔ Download complete. Mounted in container at /opt/app-root/src/.cache/huggingface"
    exit 0
  else
    echo "huggingface_hub not available in $PYTHON_BIN; falling back to Docker." >&2
  fi
fi

# Final fallback: run a disposable Docker Python to download
if command -v docker >/dev/null 2>&1; then
  echo "Using Docker fallback (python:3.11-slim) to download via huggingface-cli." >&2
  # Pass HF token through if set, and mount host cache
  DOCKER_ENV=( )
  if [[ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]]; then
    DOCKER_ENV+=( -e "HUGGINGFACE_HUB_TOKEN=${HUGGINGFACE_HUB_TOKEN}" )
  fi
  # Pass additional args via env to avoid quoting issues
  DOCKER_ENV+=( -e "HF_ARGS=$*" )
  docker run --rm \
    "${DOCKER_ENV[@]}" \
    -v "$(pwd)/hf-cache:/hf-cache" \
    -w /work \
    python:3.11-slim bash -lc "pip install --quiet 'huggingface_hub[cli]' && HF_HOME=/hf-cache TRANSFORMERS_CACHE=/hf-cache/hub huggingface-cli download '$REPO_ID' \$HF_ARGS"
  echo "✔ Download complete. Mounted in container at /opt/app-root/src/.cache/huggingface"
  exit 0
fi

echo "Error: neither huggingface-cli, python3/python, nor docker is available. Install one of them or use: python -m pip install 'huggingface_hub[cli]'" >&2
exit 1
