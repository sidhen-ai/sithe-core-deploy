# SITHE-CORE Deployment Tool

> **Not maintained (last change 2025-09).** Superseded: sithe-core no longer
> runs as a self-hosted Docker container. It runs as a worker started by the
> SIDHEN platform, and a SIDHEN device runs its services through cairn-shell.
> Nothing in the current SIDHEN deployment uses this repository. Kept for
> history; do not use it for new installs.

A bootstrap script that ran SITHE-CORE (the SIDHEN voice agent worker) in
Docker on a partner's machine.

## What it did

`install.sh`:

1. Logs in to the GitHub Container Registry with a token that has
   `read:packages`.
2. Checks Docker is running, removes an existing `sithe-core` container if you
   agree, and warns on low disk space.
3. Pulls the deployment-tools image `ghcr.io/sidhen-ai/sithe-core-deploy` and
   runs it with the Docker socket and the install directory mounted. That
   image asks for configuration, pulls the `sithe-core` image and starts the
   `sithe-core` container.

The images need a token to pull, and sithe-core has not published a new
release image since 2025, so the script is not expected to work today.

## Files

- `install.sh` — the installer. Options: `--token` (required), `--version`
  (default `latest`), `--dir` (default `/opt/sithe-core`), `--dry-run`,
  `--help`.
- `install-local-test.sh` — the same flow using a directory under your home,
  for testing on macOS.
- `install-debug.sh` — logs in and pulls the deployment image with shell
  tracing on.

## License

Copyright (c) 2025 Sidhen Limited. All rights reserved.
