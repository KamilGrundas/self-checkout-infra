#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_EXAMPLE="$ROOT_DIR/.env.example"
ENV_FILE="$ROOT_DIR/.env"

[ -f "$ENV_EXAMPLE" ] || { printf 'ERROR: missing %s\n' "$ENV_EXAMPLE" >&2; exit 1; }
if [ -e "$ENV_FILE" ]; then
  printf 'Dev env already exists; refusing to overwrite: %s\n' "$ENV_FILE"
  exit 0
fi

umask 077
temporary="$ROOT_DIR/.env.tmp.$$"
trap 'rm -f -- "$temporary"' EXIT
cp "$ENV_EXAMPLE" "$temporary"

random_hex() {
  byte_count="$1"
  head -c "$byte_count" /dev/urandom | od -An -tx1 | tr -d ' \n'
}

set_value() {
  key="$1"
  value="$2"
  next_file="$temporary.next"
  awk -v wanted="$key" -v replacement="$value" '
    BEGIN { found=0 }
    index($0, wanted "=") == 1 { print wanted "=" replacement; found=1; next }
    { print }
    END { if (!found) exit 1 }
  ' "$temporary" > "$next_file"
  mv "$next_file" "$temporary"
}

set_value SECRET_KEY "$(random_hex 32)"
set_value FIRST_SUPERUSER_PASSWORD "$(random_hex 18)"
set_value POSTGRES_PASSWORD "$(random_hex 18)"
set_value S3_ACCESS_KEY_ID "$(random_hex 12)"
set_value S3_SECRET_ACCESS_KEY "$(random_hex 24)"
mv "$temporary" "$ENV_FILE"
trap - EXIT
chmod 600 "$ENV_FILE"
printf 'Created dev-only environment file with generated secrets: %s\n' "$ENV_FILE"
