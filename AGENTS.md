# Infrastructure repository instructions

This repository is the source of truth for Docker Compose topology, service names, build contexts, infrastructure health checks, production configuration, deployment, and rollback. `compose.yml` is the base stack, `compose.override.yml` is the dev overlay, and `compose.mlflow.yml` adds optional MLflow and Label Studio services.

Read `../AGENTS.md` first. Inspect Git with `git -C self-checkout-infra`; never edit directly on `main` or `master`, combine repositories in one commit, or commit `.env`, `mydata`, database/object-store contents, credentials, private keys, tokens, or generated test reports. Do not rename Compose files or services without coordinating every consumer. Treat changes to volumes, ports, health checks, migrations, and production commands as high risk.

All Docker/Compose validation runs through `ssh dev`; never invoke Docker locally. Use `../ops/dev-sync.sh --repo infra --dry-run`, then `../ops/dev-test.sh --repo infra`. Compose configuration must pass for the exact file set being used, required services must become healthy, and deploy/rollback changes require an immutable release identifier and a documented recovery path.

Keep commits focused and imperative. Production scripts must verify `/etc/codex-environment`, accept only whitelisted arguments, avoid `eval`, and never accept local source synchronization.

The base branch is `main` as recorded in `../repos.yaml`. Create short-lived branches from a freshly fetched `origin/main`, and never implement directly on `main` or `master`. Use Conventional Commits with scopes such as `infra`, `compose`, `dev`, `ci`, `deploy`, or `rollback`.

Definition of Done: YAML and shell syntax checks pass, Compose resolves the real sibling build contexts, required services become healthy on remote dev, integration validation passes, no `.env` or secret is committed, and every volume/migration/deploy change includes compatibility and rollback notes. Production-affecting work still requires separate approval.
