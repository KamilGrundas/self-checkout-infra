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
ensure_value S3_ENDPOINT_URL 'http://s3-provider:8080'
existing_api_url="$(sed -n 's/^VITE_API_URL=//p' "$ENV_FILE" | tail -n 1)"
ensure_value BACKEND_PUBLIC_URL "${existing_api_url:-http://localhost:8000}"
case "$existing_api_url" in
  *:8000)
    default_ml_api_url="${existing_api_url%:8000}:8001"
    default_s3_public_url="${existing_api_url%:8000}:8082"
    ;;
  *)
    default_ml_api_url='http://localhost:8001'
    default_s3_public_url='http://localhost:8082'
    ;;
esac
ensure_value VITE_ML_API_URL "$default_ml_api_url"
ensure_value S3_PUBLIC_BASE_URL "$default_s3_public_url"
default_mlflow_allowed_hosts='mlflow:5000,localhost:5000,localhost:5002,127.0.0.1:5000,127.0.0.1:5002'
default_mlflow_cors_allowed_origins='http://localhost:5002,http://127.0.0.1:5002'
ensure_value MLFLOW_SERVER_ALLOWED_HOSTS "$default_mlflow_allowed_hosts"
ensure_value MLFLOW_SERVER_CORS_ALLOWED_ORIGINS "$default_mlflow_cors_allowed_origins"
if [ -n "${DEV_PUBLIC_HOST:-}" ]; then
  case "$DEV_PUBLIC_HOST" in
    *[!A-Za-z0-9.-]*)
      printf 'ERROR: DEV_PUBLIC_HOST must be a hostname or IPv4 address without a scheme or port\n' >&2
      exit 1
      ;;
  esac
  set_value FRONTEND_HOST "http://$DEV_PUBLIC_HOST:5173"
  set_value BACKEND_PUBLIC_URL "http://$DEV_PUBLIC_HOST:8000"
  set_value VITE_API_URL "http://$DEV_PUBLIC_HOST:8000"
  set_value VITE_ML_API_URL "http://$DEV_PUBLIC_HOST:8001"
  set_value S3_PUBLIC_BASE_URL "http://$DEV_PUBLIC_HOST:8082"
  set_value BACKEND_CORS_ORIGINS "http://$DEV_PUBLIC_HOST:5173"
  set_value MLFLOW_SERVER_ALLOWED_HOSTS "$default_mlflow_allowed_hosts,$DEV_PUBLIC_HOST:5002"
  set_value MLFLOW_SERVER_CORS_ALLOWED_ORIGINS "$default_mlflow_cors_allowed_origins,http://$DEV_PUBLIC_HOST:5002"
fi
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
