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

remove_value() {
  key="$1"
  next_file="$ENV_FILE.next.$$"
  awk -v unwanted="$key" 'index($0, unwanted "=") != 1 { print }' \
    "$ENV_FILE" > "$next_file"
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

for obsolete_key in \
  MODEL_CACHE_DIR \
  S3_LABEL_STUDIO_EXPORT_BUCKET \
  MLFLOW_TRACKING_URI \
  MLFLOW_BACKEND_STORE_URI \
  MLFLOW_ARTIFACT_ROOT \
  MLFLOW_SERVER_ALLOWED_HOSTS \
  MLFLOW_SERVER_CORS_ALLOWED_ORIGINS \
  MLFLOW_REGISTERED_MODEL_NAME \
  MLFLOW_SHELF_EXPERIMENT_NAME \
  MLFLOW_SHELF_MODEL_NAME \
  LABEL_STUDIO_URL \
  LABEL_STUDIO_USERNAME \
  LABEL_STUDIO_PASSWORD \
  LABEL_STUDIO_API_KEY \
  LABEL_STUDIO_SCALE_PROJECT_TITLE \
  LABEL_STUDIO_SHELF_PROJECT_TITLE \
  LABEL_STUDIO_EXTERNAL_PROJECT_TITLE \
  DEV_PUBLIC_HOST
do
  remove_value "$obsolete_key"
done

set_value PROJECT_NAME 'Self Checkout Backend'
set_value ENVIRONMENT local
set_value FRONTEND_HOST 'https://dev.admin.teik.pl'
set_value BACKEND_PUBLIC_URL 'https://dev.api.teik.pl'
set_value VITE_API_URL 'https://dev.api.teik.pl'
set_value VITE_ML_API_URL 'https://dev.ml.teik.pl'
set_value BACKEND_CORS_ORIGINS 'https://dev.admin.teik.pl'
set_value S3_PUBLIC_BASE_URL 'https://dev.s3-api.teik.pl'
ensure_value S3_ENDPOINT_URL 'http://s3-provider:8080'
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
printf 'Repaired non-secret dev environment metadata in %s\n' "$ENV_FILE"
