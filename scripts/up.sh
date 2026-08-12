#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

docker compose \
  -f compose.yml \
  -f compose.override.yml \
  -f compose.s3.dev.yml \
  up --build -d --remove-orphans
