#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

dry_run=false
replace_dev=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --replace-dev) replace_dev=true ;;
    *) die "Unsupported S3 refresh argument: $arg" ;;
  esac
done

validate_direction
init_log
for name in PROD_S3_ENDPOINT_URL PROD_S3_BUCKET PROD_S3_ACCESS_KEY_ID \
  PROD_S3_SECRET_ACCESS_KEY DEV_S3_ENDPOINT_URL DEV_S3_BUCKET \
  DEV_S3_ACCESS_KEY_ID DEV_S3_SECRET_ACCESS_KEY PROD_S3_ACCESS_MODE; do
  require_var "$name"
done
[ "$PROD_S3_ACCESS_MODE" = read-only ] ||
  die "Production S3 access must be independently attested as read-only"
[ "$PROD_S3_ENDPOINT_URL/$PROD_S3_BUCKET" != "$DEV_S3_ENDPOINT_URL/$DEV_S3_BUCKET" ] ||
  die "S3 source and target endpoint/bucket pairs are identical"

print_direction_plan
log "S3 plan: list/read prod bucket $PROD_S3_BUCKET, copy object bodies and metadata to dev bucket $DEV_S3_BUCKET"
log "Credentials, policies, bucket configuration, and environment files are not copied"
[ "$replace_dev" = false ] ||
  log "Replace mode requested: existing dev objects will be deleted only after confirmation"

state_dir="${REFRESH_STATE_DIR:-./refresh-state}"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
plan_id="$(printf '%s' "$PROD_SOURCE_ID|$DEV_TARGET_ID|$PROD_S3_BUCKET|$DEV_S3_BUCKET" | shasum -a 256 | awk '{print $1}')"
dry_run_stamp="$state_dir/s3-$plan_id.dry-run"

if [ "$dry_run" = true ]; then
  : > "$dry_run_stamp"
  chmod 600 "$dry_run_stamp"
  log "DRY-RUN: validated fixed direction and recorded plan $plan_id; no object mutation executed"
  exit 0
fi

require_command aws
require_command shasum
[ "$replace_dev" = false ] || [ -f "$dry_run_stamp" ] ||
  die "Replace mode requires a successful prior dry-run for the same endpoints and buckets"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/self-checkout-s3-prod-to-dev.XXXXXX")"
chmod 700 "$work_dir"
trap 'rm -rf -- "$work_dir"' EXIT
manifest_dir="${REFRESH_MANIFEST_DIR:-./refresh-manifests}"
mkdir -p "$manifest_dir"
chmod 700 "$manifest_dir"
manifest_id="$(date -u +%Y%m%dT%H%M%SZ)-$plan_id"
source_manifest="$manifest_dir/$manifest_id-source.json"
target_manifest="$manifest_dir/$manifest_id-target.json"

AWS_ACCESS_KEY_ID="$PROD_S3_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$PROD_S3_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="${PROD_S3_SESSION_TOKEN:-}" \
AWS_DEFAULT_REGION="${PROD_S3_REGION:-us-east-1}" \
aws --endpoint-url "$PROD_S3_ENDPOINT_URL" s3api list-objects-v2 \
  --bucket "$PROD_S3_BUCKET" --output json > "$source_manifest"
chmod 600 "$source_manifest"

AWS_ACCESS_KEY_ID="$PROD_S3_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$PROD_S3_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="${PROD_S3_SESSION_TOKEN:-}" \
AWS_DEFAULT_REGION="${PROD_S3_REGION:-us-east-1}" \
aws --endpoint-url "$PROD_S3_ENDPOINT_URL" s3 sync \
  "s3://$PROD_S3_BUCKET" "$work_dir/objects" --no-progress

if [ "$replace_dev" = true ]; then
  confirm_exact "ODTWÓRZ DEV S3 $DEV_S3_BUCKET"
  AWS_ACCESS_KEY_ID="$DEV_S3_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$DEV_S3_SECRET_ACCESS_KEY" \
  AWS_SESSION_TOKEN="${DEV_S3_SESSION_TOKEN:-}" \
  AWS_DEFAULT_REGION="${DEV_S3_REGION:-us-east-1}" \
  aws --endpoint-url "$DEV_S3_ENDPOINT_URL" s3 rm \
    "s3://$DEV_S3_BUCKET" --recursive --no-progress
fi

AWS_ACCESS_KEY_ID="$DEV_S3_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$DEV_S3_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="${DEV_S3_SESSION_TOKEN:-}" \
AWS_DEFAULT_REGION="${DEV_S3_REGION:-us-east-1}" \
aws --endpoint-url "$DEV_S3_ENDPOINT_URL" s3 sync \
  "$work_dir/objects" "s3://$DEV_S3_BUCKET" --no-progress

source_count="$(find "$work_dir/objects" -type f | wc -l | tr -d ' ')"
source_bytes="$(
  find "$work_dir/objects" -type f -exec sh -c \
    'for file do wc -c < "$file"; done' sh {} + |
    awk '{sum += $1} END {print sum + 0}'
)"

AWS_ACCESS_KEY_ID="$DEV_S3_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$DEV_S3_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="${DEV_S3_SESSION_TOKEN:-}" \
AWS_DEFAULT_REGION="${DEV_S3_REGION:-us-east-1}" \
aws --endpoint-url "$DEV_S3_ENDPOINT_URL" s3api list-objects-v2 \
  --bucket "$DEV_S3_BUCKET" --output json > "$target_manifest"
chmod 600 "$target_manifest"

target_count="$(
  AWS_ACCESS_KEY_ID="$DEV_S3_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$DEV_S3_SECRET_ACCESS_KEY" \
  AWS_SESSION_TOKEN="${DEV_S3_SESSION_TOKEN:-}" \
  AWS_DEFAULT_REGION="${DEV_S3_REGION:-us-east-1}" \
  aws --endpoint-url "$DEV_S3_ENDPOINT_URL" s3api list-objects-v2 \
    --bucket "$DEV_S3_BUCKET" --query 'length(Contents || `[]`)' --output text
)"
target_bytes="$(
  AWS_ACCESS_KEY_ID="$DEV_S3_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$DEV_S3_SECRET_ACCESS_KEY" \
  AWS_SESSION_TOKEN="${DEV_S3_SESSION_TOKEN:-}" \
  AWS_DEFAULT_REGION="${DEV_S3_REGION:-us-east-1}" \
  aws --endpoint-url "$DEV_S3_ENDPOINT_URL" s3api list-objects-v2 \
    --bucket "$DEV_S3_BUCKET" --query 'sum(Contents[].Size) || `0`' --output text
)"
[ "$target_count" -ge "$source_count" ] ||
  die "Target object count $target_count is lower than copied source count $source_count"
[ "$target_bytes" -ge "$source_bytes" ] ||
  die "Target size $target_bytes is lower than copied source size $source_bytes"

sample_file="$(find "$work_dir/objects" -type f -print -quit)"
if [ -n "$sample_file" ]; then
  sample_key="${sample_file#"$work_dir/objects/"}"
  AWS_ACCESS_KEY_ID="$DEV_S3_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$DEV_S3_SECRET_ACCESS_KEY" \
  AWS_SESSION_TOKEN="${DEV_S3_SESSION_TOKEN:-}" \
  AWS_DEFAULT_REGION="${DEV_S3_REGION:-us-east-1}" \
  aws --endpoint-url "$DEV_S3_ENDPOINT_URL" s3 cp \
    "s3://$DEV_S3_BUCKET/$sample_key" "$work_dir/sample.target" --no-progress
  [ "$(shasum -a 256 "$sample_file" | awk '{print $1}')" = \
    "$(shasum -a 256 "$work_dir/sample.target" | awk '{print $1}')" ] ||
    die "Target sample content differs from source"
fi

log "S3 refresh completed: copied_objects=$source_count copied_bytes=$source_bytes target_objects=$target_count target_bytes=$target_bytes"
log "Source and target manifests retained in protected storage; ETag was not treated as a content checksum"
