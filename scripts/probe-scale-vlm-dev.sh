#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ENDPOINT_URL="${1:-}"

case "$ENDPOINT_URL" in
  http://*|https://*) ;;
  *) printf 'ERROR: endpoint must use http or https\n' >&2; exit 2 ;;
esac
case "$ENDPOINT_URL" in
  *'#'*|*'@'*) printf 'ERROR: endpoint must not contain a fragment or credentials\n' >&2; exit 2 ;;
esac

cd "$ROOT_DIR"

docker compose -f compose.yml -f compose.override.yml -f compose.s3.dev.yml -f compose.mlflow.yml exec -T \
  -e SCALE_VLM_PROBE_URL="$ENDPOINT_URL" ml python - <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import socket
from pathlib import PurePosixPath
from typing import Any
from urllib.parse import urlsplit

import httpx
from botocore.exceptions import BotoCoreError

from app.core.config import settings
from app.core.object_storage import get_object_storage

MAX_RESPONSE_BYTES = 1_048_576
endpoint = os.environ["SCALE_VLM_PROBE_URL"]
parsed = urlsplit(endpoint)
if parsed.scheme not in {"http", "https"} or parsed.username or parsed.password or parsed.fragment:
    raise SystemExit("ERROR: unsafe endpoint URL")
if not settings.S3_SCALE_BUCKET:
    raise SystemExit("ERROR: S3_SCALE_BUCKET is not configured")

try:
    endpoint_address = (
        parsed.hostname or "",
        parsed.port or (443 if parsed.scheme == "https" else 80),
    )
    with socket.create_connection(
        endpoint_address,
        timeout=5.0,
    ):
        pass
except OSError as exc:
    print(f"VLM_TCP_CONNECT=failed:{type(exc).__name__}")
    raise SystemExit("ERROR: inference endpoint is unreachable") from None
print("VLM_TCP_CONNECT=ok")

storage = get_object_storage()
selected: tuple[str, bytes, str] | None = None
total_objects = 0
image_objects = 0
empty_images = 0
try:
    for item in storage.list_objects(settings.S3_SCALE_BUCKET):
        total_objects += 1
        filename = PurePosixPath(item.object_name).name.lower()
        metadata = storage.head_object(settings.S3_SCALE_BUCKET, item.object_name)
        content_type = metadata.content_type or ""
        if not content_type.startswith("image/") and PurePosixPath(
            filename
        ).suffix not in {
            ".jpg",
            ".jpeg",
            ".png",
            ".webp",
        }:
            continue
        image_objects += 1
        if "0000-empty" in filename:
            empty_images += 1
            continue
        if item.size <= 0:
            continue
        selected = (
            item.object_name,
            storage.get_bytes(settings.S3_SCALE_BUCKET, item.object_name),
            content_type or "application/octet-stream",
        )
        break
except BotoCoreError as exc:
    print(f"S3_ENDPOINT_HOST={urlsplit(str(settings.S3_ENDPOINT_URL)).hostname or ''}")
    print(f"S3_ERROR_TYPE={type(exc).__name__}")
    raise SystemExit("ERROR: scale object storage is unavailable") from None

if selected is None:
    print(f"S3_ENDPOINT_HOST={urlsplit(str(settings.S3_ENDPOINT_URL)).hostname or ''}")
    print(f"SCALE_OBJECTS={total_objects}")
    print(f"SCALE_IMAGES={image_objects}")
    print(f"SCALE_EMPTY_IMAGES={empty_images}")
    raise SystemExit("ERROR: no non-empty scale image is available")

object_name, image_bytes, content_type = selected
with httpx.Client(
    follow_redirects=False,
    timeout=httpx.Timeout(connect=5.0, read=120.0, write=30.0, pool=5.0),
) as client:
    with client.stream(
        "POST",
        endpoint,
        data={
            "prompt": "Opisz krótko produkt widoczny na obrazie.",
            "max_tokens": "512",
        },
        files={
            "image": (
                PurePosixPath(object_name).name,
                image_bytes,
                content_type,
            )
        },
    ) as response:
        chunks: list[bytes] = []
        total = 0
        for chunk in response.iter_bytes():
            total += len(chunk)
            if total > MAX_RESPONSE_BYTES:
                raise SystemExit("ERROR: response exceeded 1048576 bytes")
            chunks.append(chunk)
        body = b"".join(chunks)

def shape(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: shape(item) for key, item in value.items()}
    if isinstance(value, list):
        return [shape(value[0])] if value else []
    if isinstance(value, str):
        return {"type": "string", "length": len(value)}
    if value is None:
        return "null"
    return type(value).__name__

print(f"HTTP_STATUS={response.status_code}")
print(f"CONTENT_TYPE={response.headers.get('content-type', '')}")
print(f"RESPONSE_BYTES={len(body)}")
print(f"RESPONSE_SHA256={hashlib.sha256(body).hexdigest()}")
try:
    payload = json.loads(body)
except (UnicodeDecodeError, json.JSONDecodeError):
    print("RESPONSE_SCHEMA=non-json")
else:
    print("RESPONSE_SCHEMA=" + json.dumps(shape(payload), ensure_ascii=True, sort_keys=True))
PY
