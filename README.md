# Self-checkout infrastructure

This repository owns Docker Compose topology, development validation, external
service configuration, health checks, and controlled data-refresh/reset
workflows.

## Compose topology

- `compose.yml`: application base (`backend`, `admin`, `ml`, `ml-worker`,
  migrations).
- `compose.override.yml`: dev PostgreSQL, Redis, ports, reload, and local
  volumes.
- `compose.prod.yml`: required external PostgreSQL, Redis, and S3
  configuration; no stateful service containers.
- `compose.mlflow.yml`: dev MLflow and Label Studio, included by the standard
  dev startup scripts.
- `compose.s3.dev.yml`: selected, replaceable MinIO provider for normal
  development, using the generic `s3-provider` DNS contract and the retained
  `minio-data` volume.
- `compose.s3-provider.example.yml`: provider-neutral overlay contract with an
  image/version placeholder.
- `compose.s3-contract-test.yml`: isolated automated-test fixture only.
- `compose.validation.yml`: repository builds, tests, and integration checks.

Normal dev selects the pinned MinIO overlay, while application services remain
provider-neutral through `S3_*` configuration. The overlay can be replaced
without application-code changes. Production always uses an external endpoint
and never starts MinIO.

To expose the admin UI, APIs, and MLflow to other machines on the development
LAN, set the runtime host without a scheme or port and rebuild the application
services. The repair script adds the public MLflow address to its allowed-host
and CORS-origin lists:

```bash
DEV_PUBLIC_HOST=192.0.2.10 ./scripts/repair-dev-env.sh
./scripts/up.sh
```

## Configuration

Copy `.env.example` to the remote dev host through `scripts/init-dev-env.sh`.
Production shape is documented by `.env.prod.example`; secrets must come from
the deployment secret manager rather than a committed file.

The backend uses `DATABASE_URL`. Dev Compose constructs it for local
PostgreSQL; production requires an external connection string. S3 configuration
supports endpoint, region, optional static/session credentials, TLS
verification, path-style addressing, retry/timeout settings, public delivery
base URL, and explicit dev-only bucket creation.

Classifier training and scale-image autolabeling use `TRAINING_QUEUE_URL`. Dev
Compose starts persistent Redis-backed queues and separate RQ workers. The
`ml-autolabel-worker` consumes only `scale-autolabel` with one worker process,
so local VLM requests are sequential and never block classifier training.
Production requires an external Redis connection. The API persists job state in Redis so progress remains available
across API restarts.

MLflow separates `MLFLOW_TRACKING_URI`, `MLFLOW_BACKEND_STORE_URI`, and
`MLFLOW_ARTIFACT_ROOT`. Its artifact root may be an S3 URI and receives the same
generic endpoint and credential configuration. The ML API remains healthy
without MLflow, but training, registry, and model-loading workflows require it.
Standard dev startup brings up backend, admin, ML API, ML worker, PostgreSQL,
Redis, MLflow, Label Studio, and the development mail catcher together.
The admin image receives browser-accessible `VITE_API_URL` and
`VITE_ML_API_URL` values at build time.

## Scale VLM development workflow

The VLM endpoint is application data managed by a superuser, not a build-time
frontend variable or an infrastructure secret. Configure development safely
through the backend API:

```bash
./scripts/configure-scale-vlm-dev.sh \
  http://192.168.0.29:8088/v1/files/inference 512 5 120
```

Probe the real endpoint with one non-empty image read from
`S3_SCALE_BUCKET`, while printing only status, content type, size, hash, and an
anonymized response shape:

```bash
./scripts/probe-scale-vlm-dev.sh \
  http://192.168.0.29:8088/v1/files/inference
```

The probe rejects credentials/fragments, disables redirects, bounds timeouts
and response size, and does not persist the image or raw response.

Backend OpenAPI changes must regenerate the admin client with the controlled
development container:

```bash
./scripts/generate-admin-client-dev.sh
./scripts/format-admin-dev.sh
```

The first command replaces `openapi.json` and generated `src/client/**`; the
second formats only the reviewed admin files owned by this feature. Neither
script commits or pushes changes.

## Development validation

Docker commands run only on the marked `dev` host through workspace scripts:

```bash
../ops/dev-test.sh
```

Validation starts the full dev stack, replaces normal MinIO with the isolated
S3 contract fixture, and tests bucket
availability/creation, custom endpoint, path-style addressing, write, read,
list, metadata, content type, and delete. The contract fixture is not started
by `scripts/up.sh` and is never included in production.

## Data refresh and reset

`ops/data-refresh/prod-to-dev.sh` supports `--dry-run`, `--postgres`, `--s3`,
`--mlflow`, `--all`, `--verify-only`, `--snapshot-dev`, and dev-only
`--replace-dev`. Source production access is read-only. Independent environment
markers, fixed `PROD_*`/`DEV_*` roles, exact confirmations, and distinct-target
checks prevent reverse synchronization.

`ops/reset-dev.sh` removes only allowlisted, Compose-labelled dev volumes. It
never performs system-wide pruning. See the workspace `docs/data-refresh.md`
and `docs/disaster-recovery.md` for privileges, retention, verification, and
limitations.
