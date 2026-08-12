#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ENDPOINT_URL="${1:-}"
MAX_TOKENS="${2:-512}"
CONNECT_TIMEOUT_SECONDS="${3:-5}"
READ_TIMEOUT_SECONDS="${4:-120}"

case "$ENDPOINT_URL" in
  http://*|https://*) ;;
  *) printf 'ERROR: endpoint must use http or https\n' >&2; exit 2 ;;
esac

cd "$ROOT_DIR"

docker compose -f compose.yml -f compose.override.yml -f compose.s3.dev.yml exec -T \
  -e SCALE_VLM_ENDPOINT_URL="$ENDPOINT_URL" \
  -e SCALE_VLM_MAX_TOKENS="$MAX_TOKENS" \
  -e SCALE_VLM_CONNECT_TIMEOUT="$CONNECT_TIMEOUT_SECONDS" \
  -e SCALE_VLM_READ_TIMEOUT="$READ_TIMEOUT_SECONDS" \
  backend python - <<'PY'
from __future__ import annotations

import os
from urllib.parse import urlsplit

import httpx

endpoint = os.environ["SCALE_VLM_ENDPOINT_URL"]
parsed = urlsplit(endpoint)
if (
    parsed.scheme not in {"http", "https"}
    or not parsed.hostname
    or parsed.username
    or parsed.password
    or parsed.fragment
):
    raise SystemExit("ERROR: unsafe endpoint URL")

login = httpx.post(
    "http://localhost:8000/api/v1/login/access-token",
    data={
        "username": os.environ["FIRST_SUPERUSER"],
        "password": os.environ["FIRST_SUPERUSER_PASSWORD"],
    },
    follow_redirects=False,
    timeout=10.0,
)
login.raise_for_status()
token = login.json()["access_token"]

response = httpx.put(
    "http://localhost:8000/api/v1/system-settings/autolabel",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "endpoint_url": endpoint,
        "max_tokens": int(os.environ["SCALE_VLM_MAX_TOKENS"]),
        "connect_timeout_seconds": int(os.environ["SCALE_VLM_CONNECT_TIMEOUT"]),
        "read_timeout_seconds": int(os.environ["SCALE_VLM_READ_TIMEOUT"]),
    },
    follow_redirects=False,
    timeout=10.0,
)
response.raise_for_status()
payload = response.json()
print(f"CONFIGURED={str(payload['configured']).lower()}")
print(f"ENDPOINT_HOST={urlsplit(payload['endpoint_url']).hostname or ''}")
print(f"MAX_TOKENS={payload['max_tokens']}")
print(f"CONNECT_TIMEOUT_SECONDS={payload['connect_timeout_seconds']}")
print(f"READ_TIMEOUT_SECONDS={payload['read_timeout_seconds']}")
PY
