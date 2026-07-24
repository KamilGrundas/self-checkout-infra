#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/refresh-guards.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT
printf 'prod\n' > "$work_dir/prod.marker"
printf 'dev\n' > "$work_dir/dev.marker"

export PROD_SOURCE_MARKER_FILE="$work_dir/prod.marker"
export DEV_TARGET_MARKER_FILE="$work_dir/dev.marker"
export PROD_SOURCE_ID=synthetic-prod
export DEV_TARGET_ID=synthetic-dev
export PROD_DATABASE_URL=postgresql://source.invalid/app
export DEV_DATABASE_URL=postgresql://dev.invalid/app
export DEV_DATABASE_NAME=app
export REFRESH_LOG_DIR="$work_dir/logs"

"$ROOT/ops/data-refresh/prod-to-dev.sh" --dry-run --postgres

if DEV_TARGET_MARKER_FILE="$work_dir/prod.marker" \
  "$ROOT/ops/data-refresh/prod-to-dev.sh" --dry-run --postgres >/dev/null 2>&1; then
  printf 'ERROR: dev-to-prod marker swap was not blocked\n' >&2
  exit 1
fi

if DEV_DATABASE_URL="$PROD_DATABASE_URL" \
  "$ROOT/ops/data-refresh/prod-to-dev.sh" --dry-run --postgres >/dev/null 2>&1; then
  printf 'ERROR: identical PostgreSQL source and target were not blocked\n' >&2
  exit 1
fi

printf 'Data-refresh guard tests passed\n'
