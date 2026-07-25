import os
import time
from urllib.parse import urlparse

import boto3
from botocore.exceptions import BotoCoreError, ClientError


artifact_root = os.environ["MLFLOW_ARTIFACT_ROOT"]
parsed_root = urlparse(artifact_root)
if parsed_root.scheme != "s3":
    print(f"MLflow artifact initialization is not required for {parsed_root.scheme!r}")
    raise SystemExit(0)

bucket = parsed_root.netloc
if not bucket:
    raise RuntimeError("MLFLOW_ARTIFACT_ROOT must include an S3 bucket name")

region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
create_bucket = os.environ.get("S3_CREATE_BUCKETS", "false").lower() == "true"
client = boto3.client(
    "s3",
    endpoint_url=os.environ.get("AWS_ENDPOINT_URL_S3"),
    region_name=region,
)

for attempt in range(30):
    try:
        client.head_bucket(Bucket=bucket)
        print(f"MLflow artifact bucket {bucket!r} is available")
        break
    except ClientError as error:
        code = str(error.response.get("Error", {}).get("Code", ""))
        if code not in {"404", "NoSuchBucket", "NotFound"}:
            if attempt == 29:
                raise
            time.sleep(2)
            continue
        if not create_bucket:
            raise RuntimeError(
                f"MLflow artifact bucket {bucket!r} does not exist and "
                "S3_CREATE_BUCKETS=false"
            ) from error
        create_args = {"Bucket": bucket}
        if region != "us-east-1":
            create_args["CreateBucketConfiguration"] = {
                "LocationConstraint": region
            }
        try:
            client.create_bucket(**create_args)
        except (BotoCoreError, ClientError):
            if attempt == 29:
                raise
            time.sleep(2)
            continue
        print(f"Created MLflow artifact bucket {bucket!r}")
        break
    except BotoCoreError:
        if attempt == 29:
            raise
        time.sleep(2)
else:
    raise RuntimeError(f"MLflow artifact bucket {bucket!r} is unavailable")
