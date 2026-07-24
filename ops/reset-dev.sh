#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

dry_run=false
snapshot_dev=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --snapshot-dev) snapshot_dev=true ;;
    -h|--help)
      printf 'Usage: %s [--dry-run] [--snapshot-dev]\n' "$0"
      exit 0
      ;;
    *) printf 'ERROR: unsupported argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

marker="${DEV_ENVIRONMENT_MARKER_FILE:-/etc/codex-environment}"
[ -f "$marker" ] && [ "$(tr -d '[:space:]' < "$marker")" = dev ] || {
  printf 'ERROR: reset target is not independently marked as dev\n' >&2
  exit 1
}

project="${COMPOSE_PROJECT_NAME:-self-checkout}"
case "$project" in
  *dev*|self-checkout) ;;
  *) printf 'ERROR: Compose project is not on the dev allowlist\n' >&2; exit 1 ;;
esac

volumes=(
  "${project}_app-db-data"
  "${project}_ml-model-cache"
  "${project}_mlflow-data"
  "${project}_label-studio-data"
)

printf 'DEV reset plan:\n'
printf '  project: %s\n' "$project"
printf '  stop: admin backend ml prestart db\n'
printf '  remove allowlisted volumes only:\n'
printf '    %s\n' "${volumes[@]}"
printf '  recreate stack, then run prod-to-dev import separately\n'

[ "$dry_run" = false ] || exit 0
[ "$snapshot_dev" = false ] || {
  [ -n "${DEV_DATABASE_URL:-}" ] || {
    printf 'ERROR: DEV_DATABASE_URL is required for snapshot\n' >&2
    exit 1
  }
  mkdir -p snapshots
  chmod 700 snapshots
  pg_dump "$DEV_DATABASE_URL" --format=custom \
    --file="snapshots/dev-before-reset-$(date -u +%Y%m%dT%H%M%SZ).dump"
}

printf 'Type exactly: RESET DEV %s\n> ' "$project"
IFS= read -r answer
[ "$answer" = "RESET DEV $project" ] || {
  printf 'ERROR: confirmation did not match\n' >&2
  exit 1
}

compose=(docker compose -f compose.yml -f compose.override.yml)
"${compose[@]}" stop admin backend ml prestart db
for volume in "${volumes[@]}"; do
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    owner="$(docker volume inspect "$volume" --format '{{ index .Labels "com.docker.compose.project" }}')"
    [ "$owner" = "$project" ] || {
      printf 'ERROR: volume %s is not owned by Compose project %s\n' "$volume" "$project" >&2
      exit 1
    }
    docker volume rm "$volume"
  fi
done
"${compose[@]}" up --build -d
printf 'DEV stack recreated. Run ops/data-refresh/prod-to-dev.sh for selected imports.\n'
