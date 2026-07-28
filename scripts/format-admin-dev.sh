#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ADMIN_DIR="$(CDPATH= cd -- "$ROOT_DIR/../self-checkout-admin" && pwd)"
admin_owner="$(stat -c '%u:%g' "$ADMIN_DIR")"
cd "$ROOT_DIR"

compose=(
  docker compose
  -f compose.yml
  -f compose.override.yml
  -f compose.s3-contract-test.yml
  -f compose.mlflow.yml
  -f compose.validation.yml
)

admin_files=(
  /workspace/src/components/ML/ImagesTab.tsx
  /workspace/src/components/CheckoutCounters/EditCheckoutCounter.tsx
  /workspace/src/routes/_layout/ml.tsx
  /workspace/src/routes/_layout/checkout-counters.tsx
  /workspace/src/i18n.tsx
  /workspace/tests/ml-images.spec.ts
  /workspace/tests/checkout-counter-cameras.spec.ts
)

trap '"${compose[@]}" run --rm --no-deps admin-validation chown "$admin_owner" "${admin_files[@]}"' EXIT

"${compose[@]}" run --rm --no-deps admin-validation bash -lc '
  npm ci
  npx biome check --write \
    src/components/ML/ImagesTab.tsx \
    src/components/CheckoutCounters/EditCheckoutCounter.tsx \
    src/routes/_layout/ml.tsx \
    src/routes/_layout/checkout-counters.tsx \
    src/i18n.tsx \
    tests/ml-images.spec.ts \
    tests/checkout-counter-cameras.spec.ts
'
