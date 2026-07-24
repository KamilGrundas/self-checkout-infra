# Self-checkout infrastructure

This repository owns Docker Compose topology, development validation, external
service configuration, health checks, and controlled data-refresh/reset
workflows.

## Compose topology

- `compose.yml`: application-only base (`backend`, `admin`, `ml`, migrations).
- `compose.override.yml`: dev PostgreSQL, ports, reload, and local volumes.
- `compose.prod.yml`: required external PostgreSQL and S3 configuration; no
  stateful services.
- `compose.mlflow.yml`: optional dev MLflow and Label Studio.
- `compose.s3-provider.example.yml`: provider-neutral overlay contract with an
  image/version placeholder.
- `compose.s3-contract-test.yml`: isolated automated-test fixture only.
- `compose.validation.yml`: repository builds, tests, and integration checks.

No permanent S3-compatible provider is selected. Normal dev operation points
`S3_ENDPOINT_URL` at an external endpoint or at the DNS alias supplied by an
explicit provider overlay. Production always uses an external endpoint.

## Configuration

Copy `.env.example` to the remote dev host through `scripts/init-dev-env.sh`.
Production shape is documented by `.env.prod.example`; secrets must come from
the deployment secret manager rather than a committed file.

The backend uses `DATABASE_URL`. Dev Compose constructs it for local
PostgreSQL; production requires an external connection string. S3 configuration
supports endpoint, region, optional static/session credentials, TLS
verification, path-style addressing, retry/timeout settings, public delivery
base URL, and explicit dev-only bucket creation.

MLflow separates `MLFLOW_TRACKING_URI`, `MLFLOW_BACKEND_STORE_URI`, and
`MLFLOW_ARTIFACT_ROOT`. Its artifact root may be an S3 URI and receives the same
generic endpoint and credential configuration. The ML API remains healthy
without MLflow, but training, registry, and model-loading workflows require it.

## Development validation

Docker commands run only on the marked `dev` host through workspace scripts:

```bash
../ops/dev-test.sh
../ops/dev-test.sh --ml-dev
```

Validation attaches the isolated S3 contract fixture and tests bucket
availability/creation, custom endpoint, path-style addressing, write, read,
list, metadata, content type, and delete. The fixture is not started by
`scripts/up.sh` and is never included in production.

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
