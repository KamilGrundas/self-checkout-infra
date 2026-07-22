#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

[ -f "$ENV_FILE" ] || { printf 'ERROR: missing %s\n' "$ENV_FILE" >&2; exit 1; }
umask 077

set_value() {
  key="$1"
  value="$2"
  next_file="$ENV_FILE.next.$$"
  awk -v wanted="$key" -v replacement="$value" '
    BEGIN { found=0 }
    index($0, wanted "=") == 1 { print wanted "=" replacement; found=1; next }
    { print }
    END { if (!found) print wanted "=" replacement }
  ' "$ENV_FILE" > "$next_file"
  mv "$next_file" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

set_value PROJECT_NAME 'Self Checkout Backend'
set_value ENVIRONMENT local
printf 'Repaired non-secret dev environment metadata in %s\n' "$ENV_FILE"
