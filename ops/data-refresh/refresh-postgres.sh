#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

dry_run=false
snapshot_dev=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --snapshot-dev) snapshot_dev=true ;;
    *) die "Unsupported PostgreSQL refresh argument: $arg" ;;
  esac
done

validate_direction
init_log
require_var PROD_DATABASE_URL
require_var DEV_DATABASE_URL
require_var DEV_DATABASE_NAME
[ "$PROD_DATABASE_URL" != "$DEV_DATABASE_URL" ] ||
  die "PostgreSQL source and target connection strings are identical"

print_direction_plan
log "PostgreSQL plan: connectivity/version check, custom read-only dump, dev-only restore, migrations, integrity checks"
log "Dev database selected for replacement: $DEV_DATABASE_NAME"

if [ "$dry_run" = true ]; then
  log "DRY-RUN: no dump, stop, delete, restore, migration, or source modification executed"
  exit 0
fi

require_command pg_dump
require_command pg_restore
require_command psql
require_command pg_isready
require_command shasum
require_command docker

pg_isready --dbname="$PROD_DATABASE_URL" >/dev/null
server_version="$(psql "$PROD_DATABASE_URL" -XAtc 'show server_version_num')"
client_version="$(pg_dump --version | awk '{print $NF}')"
client_major="${client_version%%.*}"
server_major="$((server_version / 10000))"
[ "$client_major" -ge "$server_major" ] ||
  die "pg_dump major $client_major is older than source PostgreSQL major $server_major"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/self-checkout-prod-to-dev.XXXXXX")"
chmod 700 "$work_dir"
trap 'rm -rf -- "$work_dir"' EXIT
dump_file="$work_dir/source.dump"

pg_dump "$PROD_DATABASE_URL" \
  --format=custom --no-owner --no-acl --serializable-deferrable \
  --file="$dump_file"
shasum -a 256 "$dump_file" > "$dump_file.sha256"
log "Production dump created in protected temporary storage; checksum recorded"

if [ "$snapshot_dev" = true ]; then
  snapshot_dir="${REFRESH_SNAPSHOT_DIR:-./refresh-snapshots}"
  mkdir -p "$snapshot_dir"
  chmod 700 "$snapshot_dir"
  snapshot_file="$snapshot_dir/dev-before-refresh-$(date -u +%Y%m%dT%H%M%SZ).dump"
  pg_dump "$DEV_DATABASE_URL" --format=custom --no-owner --no-acl \
    --file="$snapshot_file"
  chmod 600 "$snapshot_file"
  log "Pre-refresh dev snapshot retained in protected snapshot storage"
fi

log "Destructive dev step: stop application services and replace schema in $DEV_DATABASE_NAME"
confirm_exact "ODTWÓRZ DEV DB $DEV_DATABASE_NAME"

compose=(docker compose -f compose.yml -f compose.override.yml)
"${compose[@]}" stop admin backend ml
psql "$DEV_DATABASE_URL" -X -v ON_ERROR_STOP=1 \
  -c 'DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;'
pg_restore --dbname="$DEV_DATABASE_URL" --no-owner --no-acl --exit-on-error "$dump_file"
"${compose[@]}" run --rm prestart
psql "$DEV_DATABASE_URL" -XAtc \
  "select count(*) from pg_tables where schemaname = 'public'" |
  grep -Eq '^[1-9][0-9]*$'
"${compose[@]}" up -d --wait backend admin ml
log "PostgreSQL prod-to-dev refresh completed; temporary dump will be removed"
