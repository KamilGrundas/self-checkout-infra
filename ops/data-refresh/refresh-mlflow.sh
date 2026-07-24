#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

dry_run=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    *) die "Unsupported MLflow refresh argument: $arg" ;;
  esac
done

validate_direction
init_log
[ "${MLFLOW_BACKEND_INCLUDED_IN_POSTGRES:-}" = true ] ||
  die "MLflow metadata refresh requires its backend store to be included in the PostgreSQL refresh"
[ "${MLFLOW_ARTIFACTS_INCLUDED_IN_S3:-}" = true ] ||
  die "MLflow artifact refresh requires its artifact bucket to be included in the S3 refresh"

print_direction_plan
log "MLflow is restored as relational metadata plus S3 artifacts, never as an opaque server directory"
log "Production URIs and credentials are not copied; dev MLflow uses its independent configuration"
if [ "$dry_run" = true ]; then
  log "DRY-RUN: MLflow dependency mapping validated"
else
  log "MLflow data is covered by the completed PostgreSQL and S3 refresh stages"
fi
