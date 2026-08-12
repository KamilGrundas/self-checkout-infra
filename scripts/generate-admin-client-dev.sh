#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ADMIN_DIR="$(CDPATH= cd -- "$ROOT_DIR/../self-checkout-admin" && pwd)"
OPENAPI_FILE="$ADMIN_DIR/openapi.json"

cd "$ROOT_DIR"
compose=(
  docker compose
  -f compose.yml
  -f compose.override.yml
  -f compose.s3-contract-test.yml
  -f compose.validation.yml
)
admin_owner="$(stat -c '%u:%g' "$ADMIN_DIR")"

restore_admin_ownership() {
  "${compose[@]}" run --rm --no-deps admin-validation \
    chown -R "$admin_owner" /workspace/src/client /workspace/openapi.json
}

if [ "${1:-}" = "--repair-permissions-only" ]; then
  restore_admin_ownership
  printf 'Restored admin generated-file ownership.\n'
  exit 0
fi

temporary_file="$OPENAPI_FILE.next.$$"
trap 'rm -f -- "$temporary_file"; restore_admin_ownership' EXIT

"${compose[@]}" run --rm --no-deps backend-validation \
  bash -lc "uv sync --frozen --group dev >/dev/null && uv run python -c 'import json; from app.main import app; print(json.dumps(app.openapi()))'" \
  > "$temporary_file"
test -s "$temporary_file"
mv "$temporary_file" "$OPENAPI_FILE"

"${compose[@]}" run --rm --no-deps admin-validation \
  bash -lc 'npm ci && npm run generate-client'

printf 'Generated admin API client from the running development backend OpenAPI.\n'
