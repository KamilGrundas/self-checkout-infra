#!/usr/bin/env bash

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command is unavailable: $1"
}

require_var() {
  name="$1"
  [ -n "${!name:-}" ] || die "Required configuration is missing: $name"
}

read_marker() {
  marker_file="$1"
  [ -f "$marker_file" ] || die "Environment marker does not exist: $marker_file"
  tr -d '[:space:]' < "$marker_file"
}

validate_direction() {
  require_var PROD_SOURCE_MARKER_FILE
  require_var DEV_TARGET_MARKER_FILE
  require_var PROD_SOURCE_ID
  require_var DEV_TARGET_ID

  [ "$(read_marker "$PROD_SOURCE_MARKER_FILE")" = prod ] ||
    die "Source marker must contain exactly 'prod'"
  [ "$(read_marker "$DEV_TARGET_MARKER_FILE")" = dev ] ||
    die "Target marker must contain exactly 'dev'"
  [ "$PROD_SOURCE_ID" != "$DEV_TARGET_ID" ] ||
    die "Source and target identifiers must differ"
  case "$DEV_TARGET_ID" in
    *prod*|*production*) die "Target identifier looks like production" ;;
    *dev*) ;;
    *) die "Target identifier must be independently marked as development" ;;
  esac
}

init_log() {
  log_root="${REFRESH_LOG_DIR:-./refresh-logs}"
  mkdir -p "$log_root"
  chmod 700 "$log_root"
  REFRESH_LOG_FILE="$log_root/refresh-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
  : > "$REFRESH_LOG_FILE"
  chmod 600 "$REFRESH_LOG_FILE"
  export REFRESH_LOG_FILE
}

log() {
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"
  printf '%s\n' "$line"
  [ -z "${REFRESH_LOG_FILE:-}" ] || printf '%s\n' "$line" >> "$REFRESH_LOG_FILE"
}

confirm_exact() {
  expected="$1"
  printf 'Type exactly: %s\n> ' "$expected"
  IFS= read -r answer
  [ "$answer" = "$expected" ] || die "Confirmation did not match"
}

print_direction_plan() {
  log "Direction: prod($PROD_SOURCE_ID) -> dev($DEV_TARGET_ID)"
  log "Production source is read-only; credentials and environment files are excluded"
}
