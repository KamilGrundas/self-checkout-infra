#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"
compose=(docker compose -f compose.yml -f compose.override.yml -f compose.s3-contract-test.yml)
source_db=self_checkout_synthetic_prod_source
target_db=self_checkout_synthetic_dev_target
dump_file="$(mktemp "${TMPDIR:-/tmp}/synthetic-refresh.XXXXXX.dump")"
chmod 600 "$dump_file"

cleanup() {
  rm -f -- "$dump_file"
  "${compose[@]}" exec -T db sh -ec \
    "psql -U \"\$POSTGRES_USER\" -d postgres -v ON_ERROR_STOP=1 \
      -c 'DROP DATABASE IF EXISTS $source_db WITH (FORCE)' \
      -c 'DROP DATABASE IF EXISTS $target_db WITH (FORCE)'" >/dev/null
}
trap cleanup EXIT

"${compose[@]}" exec -T db sh -ec \
  "psql -U \"\$POSTGRES_USER\" -d postgres -v ON_ERROR_STOP=1 \
    -c 'DROP DATABASE IF EXISTS $source_db WITH (FORCE)' \
    -c 'DROP DATABASE IF EXISTS $target_db WITH (FORCE)' \
    -c 'CREATE DATABASE $source_db' \
    -c 'CREATE DATABASE $target_db'"
"${compose[@]}" exec -T db sh -ec \
  "psql -U \"\$POSTGRES_USER\" -d $source_db -v ON_ERROR_STOP=1 \
    -c \"CREATE TABLE domain_data (id integer PRIMARY KEY, payload text NOT NULL)\" \
    -c \"INSERT INTO domain_data VALUES (1, 'unchanged-domain-payload')\""
"${compose[@]}" exec -T db sh -ec \
  "pg_dump -U \"\$POSTGRES_USER\" --format=custom --no-owner --no-acl $source_db" \
  > "$dump_file"
"${compose[@]}" exec -T db sh -ec \
  "pg_restore -U \"\$POSTGRES_USER\" --dbname=$target_db --no-owner --no-acl --exit-on-error" \
  < "$dump_file"

payload="$(
  "${compose[@]}" exec -T db sh -ec \
    "psql -U \"\$POSTGRES_USER\" -d $target_db -XAtc 'SELECT payload FROM domain_data WHERE id = 1'"
)"
[ "$payload" = unchanged-domain-payload ] || {
  printf 'ERROR: synthetic PostgreSQL restore changed domain data\n' >&2
  exit 1
}
printf 'Synthetic PostgreSQL prod-to-dev restore passed; domain data unchanged\n'
