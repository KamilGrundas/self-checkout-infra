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

random_hex() {
  byte_count="$1"
  head -c "$byte_count" /dev/urandom | od -An -tx1 | tr -d ' \n'
}

ensure_value() {
  key="$1"
  value="$2"
  grep -Eq "^${key}=.+" "$ENV_FILE" || set_value "$key" "$value"
}

set_value PROJECT_NAME 'Self Checkout Backend'
set_value ENVIRONMENT local
set_value S3_ENDPOINT_URL 'http://s3-provider:8080'
ensure_value S3_REGION us-east-1
ensure_value S3_BUCKET product-images
ensure_value S3_ACCESS_KEY_ID "$(random_hex 12)"
ensure_value S3_SECRET_ACCESS_KEY "$(random_hex 24)"
ensure_value S3_USE_SSL false
ensure_value S3_FORCE_PATH_STYLE true
ensure_value S3_VERIFY_TLS true
ensure_value S3_CREATE_BUCKETS true
ensure_value S3_SHELF_BUCKET session-images
ensure_value S3_SCALE_BUCKET scale-images
ensure_value S3_EXTERNAL_BUCKET uploaded-images
ensure_value S3_TRAINING_BUCKET training-data
ensure_value S3_LABEL_STUDIO_EXPORT_BUCKET labelstudio-exports
ensure_value MLFLOW_BACKEND_STORE_URI 'sqlite:////mlflow/mlflow.db'
ensure_value MLFLOW_ARTIFACT_ROOT 's3://mlflow-artifacts'
printf 'Repaired non-secret dev environment metadata in %s\n' "$ENV_FILE"
