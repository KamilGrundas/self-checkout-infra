#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Override only this process; normal dev startup keeps its configured external
# endpoint or provider overlay.
export S3_ENDPOINT_URL=http://s3-contract-test:4566
export S3_ACCESS_KEY_ID=contract-test
export S3_SECRET_ACCESS_KEY=contract-test
export S3_USE_SSL=false
export S3_FORCE_PATH_STYLE=true
export S3_VERIFY_TLS=true

files="-f compose.yml -f compose.override.yml -f compose.s3-contract-test.yml"

# shellcheck disable=SC2086
docker compose $files up --build -d --remove-orphans
