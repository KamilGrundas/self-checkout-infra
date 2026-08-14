# Self-checkout infrastructure

This repository owns Docker Compose topology, development startup, validation,
health checks, deployment, and rollback controls.

## Compose topology

- `compose.yml` defines backend, admin, ML API, training worker, autolabel worker;
- `compose.override.yml` adds development PostgreSQL, Redis, mail catcher, ports, and live reload;
- `compose.s3.dev.yml` selects the replaceable development S3-compatible provider;
- `compose.s3-contract-test.yml` provides isolated contract-test storage;
- `compose.validation.yml` defines repository validation containers;
- `compose.prod.yml` configures application containers for external PostgreSQL,
  Redis, and S3-compatible dependencies.

The stack contains no MLflow or Label Studio service. Native labels, dataset
releases, model artifacts, model metrics, and active-version metadata live in
the configured generic S3 buckets.

## Development

Run from `dev` through the parent workspace controls:

```bash
./scripts/init-dev-env.sh
./scripts/up.sh
./scripts/status-dev.sh
./scripts/validate-dev.sh
```

The standard runtime is `compose.yml + compose.override.yml +
compose.s3.dev.yml`. Validation uses the isolated contract-test overlay and is
temporary; always restore the standard runtime after validation.

All long-running services in the standard development runtime use the
`unless-stopped` restart policy. Because the Docker service is enabled on the
development host, PostgreSQL, Redis, object storage, backend, admin, ML API,
and both ML workers start again automatically after a host reboot. `prestart`
is intentionally a one-shot migration container and runs during controlled
`scripts/up.sh` executions rather than Docker daemon restarts.

## Configuration

Copy `.env.example` only on `dev`. It contains placeholders for the database,
backend/admin URLs, Redis queue, and generic S3 contract. The application uses
separate S3 buckets for product images, shelf snapshots, scale snapshots,
labeled uploads, and training data/models. No provider-specific application
setting is permitted.

Production starts no database or object-storage provider. It accepts only
external stateful dependencies and approved immutable application images.

## Data refresh and reset

`ops/data-refresh/prod-to-dev.sh` supports one-way PostgreSQL and S3 refreshes
only. It never copies infrastructure secrets or permits a dev-to-prod direction.
`ops/reset-dev.sh` operates only on allowlisted development volumes after
environment and Compose-project verification.

Never run Docker locally; all Compose validation belongs on `ssh dev`.
