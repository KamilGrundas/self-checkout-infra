#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

dry_run=false
postgres=false
s3=false
mlflow=false
verify_only=false
snapshot_dev=false
replace_dev=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --postgres) postgres=true ;;
    --s3) s3=true ;;
    --mlflow) mlflow=true ;;
    --all) postgres=true; s3=true; mlflow=true ;;
    --verify-only) verify_only=true ;;
    --snapshot-dev) snapshot_dev=true ;;
    --replace-dev) replace_dev=true ;;
    -h|--help)
      printf 'Usage: %s [--dry-run] [--postgres|--s3|--mlflow|--all|--verify-only] [--snapshot-dev] [--replace-dev]\n' "$0"
      exit 0
      ;;
    *) die "Unsupported argument: $1" ;;
  esac
  shift
done

validate_direction
if [ "$verify_only" = true ]; then
  exec "$SCRIPT_DIR/verify-refresh.sh"
fi
[ "$postgres" = true ] || [ "$s3" = true ] || [ "$mlflow" = true ] ||
  die "Select --postgres, --s3, --mlflow, --all, or --verify-only"

common_args=()
[ "$dry_run" = false ] || common_args+=(--dry-run)
if [ "$postgres" = true ]; then
  pg_args=("${common_args[@]}")
  [ "$snapshot_dev" = false ] || pg_args+=(--snapshot-dev)
  "$SCRIPT_DIR/refresh-postgres.sh" "${pg_args[@]}"
fi
if [ "$s3" = true ]; then
  s3_args=("${common_args[@]}")
  [ "$replace_dev" = false ] || s3_args+=(--replace-dev)
  "$SCRIPT_DIR/refresh-s3.sh" "${s3_args[@]}"
fi
if [ "$mlflow" = true ]; then
  "$SCRIPT_DIR/refresh-mlflow.sh" "${common_args[@]}"
fi
[ "$dry_run" = true ] || "$SCRIPT_DIR/verify-refresh.sh"
