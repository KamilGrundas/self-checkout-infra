# Infrastructure repository instructions

This repository owns portable service topology, Compose examples, health checks,
and environment-independent deployment contracts. Start from the workspace root
when it is available, read its instructions, then read this file. Parent
instructions govern local operations only; do not copy absolute paths, host
policy, selected runtime, addresses, domains, proxy configuration, identity
provider, or inference provider into this repository.

Work on `main`, preserve existing changes, and keep this repository's commit
separate from other components. Do not create task branches or pull requests in
the standard workflow. Show exact changes and validation before a user-approved
commit; push only with explicit publication approval. Never reset, clean, stash
automatically, force-push, or rewrite history.

## Compose contract

Compose files use the standard Compose Specification and must work with both
`docker compose` and `podman compose`. A local environment selects its
runtime and owns the active entrypoint. Portable examples bind web services to
`127.0.0.1` and never publish PostgreSQL or Redis. Every environment has an
explicit project name and its own default network, volumes, data, configuration,
and secrets.

The versioned Compose files are the reusable topology source. Do not create
host-specific overlays, hostname mappings, trust stores, proxy rules, or
environment entrypoints here. Those are ignored local operator configuration.
Examples use placeholders only; `.env`, keys, data, backups, and generated
reports remain untracked.

## Service boundaries

Application storage is generic S3-compatible storage. Configuration supports
an external endpoint and a replaceable provider overlay without selecting a
vendor in application code. Production stateful dependencies are external and
must use separately provisioned data.

Autolabeling uses a generic OpenAI-compatible VLM inference provider. Do not
encode a provider product name in service names, environment variables, API
routes, UI contracts, or portable documentation.

Before an authorized environment change, validate the exact Compose entrypoint
with `compose config`, check script and YAML syntax, and run relevant tests.
A configuration check is not a deployment. Production work, migration, data
refresh, volume removal, or backup changes require separate explicit approval
and a reviewed restore procedure.
