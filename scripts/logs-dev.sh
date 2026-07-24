#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

service="${1:-}"
tail_lines="${2:-200}"
case "$service" in
  admin|backend|db|label-studio|mailcatcher|ml|mlflow|prestart|s3-contract-test) ;;
  *) printf 'ERROR: unsupported service: %s\n' "$service" >&2; exit 2 ;;
esac
case "$tail_lines" in
  ''|*[!0-9]*) printf 'ERROR: tail must be numeric\n' >&2; exit 2 ;;
esac
[ "$tail_lines" -ge 1 ] && [ "$tail_lines" -le 1000 ] || { printf 'ERROR: tail must be between 1 and 1000\n' >&2; exit 2; }

docker compose -f compose.yml -f compose.override.yml -f compose.mlflow.yml logs --no-color --tail "$tail_lines" "$service"
