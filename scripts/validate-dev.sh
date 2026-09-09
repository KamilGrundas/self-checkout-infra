#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if docker compose version >/dev/null 2>&1; then
  compose_runtime=(docker compose)
elif podman compose version >/dev/null 2>&1; then
  compose_runtime=(podman compose)
else
  printf '%s\n' 'ERROR: docker compose or podman compose is required' >&2
  exit 127
fi

validation_project="self-checkout-validation-$$"
compose=("${compose_runtime[@]}" -p "$validation_project" -f compose.yml -f compose.s3-contract-test.yml -f compose.validation.yml)

cleanup() {
  "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${compose[@]}" config --quiet

selected=("$@")
if [ "${#selected[@]}" -eq 0 ]; then
  selected=(admin backend client infra ml)
fi

for key in "${selected[@]}"; do
  case "$key" in
    admin|backend|client|infra|ml) ;;
    *) printf 'ERROR: unsupported repository key: %s\n' "$key" >&2; exit 2 ;;
  esac
done

for key in "${selected[@]}"; do
  case "$key" in
    admin) "${compose[@]}" run --rm --build admin-validation ;;
    backend) "${compose[@]}" run --rm --build backend-validation ;;
    client) "${compose[@]}" run --rm --build client-validation ;;
    infra)
      "${compose[@]}" config --quiet
      ./tests/dev-restart-policies.sh
      ./tests/data-refresh-guards.sh
      ./tests/postgres-refresh-synthetic.sh
      ;;
    ml) "${compose[@]}" run --rm --build ml-validation ;;
  esac
done

"${compose[@]}" run --rm --build s3-contract-validation
"${compose[@]}" run --rm --build integration-validation
