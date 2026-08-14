#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

compose=(docker compose -f compose.yml -f compose.override.yml -f compose.s3.dev.yml)
config_json="$("${compose[@]}" config --format json)"

python3 -c '
import json
import sys

config = json.load(sys.stdin)
services = config.get("services", {})
required = (
    "admin",
    "backend",
    "db",
    "mailcatcher",
    "ml",
    "ml-autolabel-worker",
    "ml-worker",
    "redis",
    "s3-provider",
)
invalid = {
    name: services.get(name, {}).get("restart")
    for name in required
    if services.get(name, {}).get("restart") != "unless-stopped"
}
if invalid:
    for name, policy in invalid.items():
        print(f"ERROR: {name} restart policy is {policy!r}, expected 'unless-stopped'", file=sys.stderr)
    raise SystemExit(1)
if services.get("prestart", {}).get("restart") not in (None, "no"):
    print("ERROR: prestart must remain a one-shot container", file=sys.stderr)
    raise SystemExit(1)
print("Development restart policies passed")
' <<<"$config_json"
