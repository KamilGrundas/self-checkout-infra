# Self-checkout infrastructure

This repository defines portable Compose topology and integration tooling for
the self-checkout components. It is deliberately independent of a specific
host, container runtime, proxy, OIDC implementation, VLM provider, and
S3-compatible provider.

## Compose topology

- `compose.yml` defines application services and their portable contracts.
- `compose.override.yml` adds isolated development PostgreSQL, Redis, and
  mail capture with loopback-only web bindings.
- `compose.s3.dev.yml` selects a replaceable development-only
  S3-compatible provider.
- `compose.s3-provider.example.yml` is a provider-neutral overlay template.
- `compose.validation.yml` is isolated validation tooling.
- `compose.prod.yml` configures application services for externally managed
  production state.

Use a selected local Compose runtime with the relevant files, for example:

```bash
docker compose -f compose.yml -f compose.override.yml -f compose.s3.dev.yml config
# or
podman compose -f compose.yml -f compose.override.yml -f compose.s3.dev.yml config
```

The local operator supplies the explicit project name and environment
separation. Those choices are intentionally outside this repository.

## Configuration

Copy `.env.example` only into a local ignored environment. It contains safe
placeholders and loopback browser URLs. Browser-facing API URLs are configured
independently; internal service DNS names are not valid browser URLs.

PostgreSQL and Redis stay on the Compose project network and are not published
to the host. Application storage uses a generic S3-compatible contract.
Autolabeling calls a replaceable OpenAI-compatible VLM inference provider; its
endpoint and token are application configuration and never appear in this
repository's host-specific topology.

Production starts no database, Redis, or object-storage provider. It accepts
only externally managed stateful dependencies and approved immutable images.
