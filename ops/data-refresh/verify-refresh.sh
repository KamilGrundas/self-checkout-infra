#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

validate_direction
init_log
print_direction_plan
log "Verify dev PostgreSQL connectivity, application health, and S3 readability"

if [ -n "${DEV_DATABASE_URL:-}" ]; then
  require_command psql
  psql "$DEV_DATABASE_URL" -XAtc 'select 1' | grep -qx 1
fi
if [ -n "${DEV_HEALTHCHECK_URL:-}" ]; then
  require_command curl
  curl -fsS "$DEV_HEALTHCHECK_URL" >/dev/null
fi
log "Refresh verification completed"
