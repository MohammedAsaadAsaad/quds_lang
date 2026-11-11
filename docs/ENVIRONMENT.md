# Managed cloud environment

The prepared instance uses Dart **3.13.7**, extracted from the official Docker
image pinned at:

```text
dart@sha256:854f3c50b1cbd4a5a54c9fa67d4f5b6702ac49b4a26d21a80e7712a72528b215
```

Docker verifies image/layer digests; normal proxy and TLS verification remain
in force. The SDK lives at `/workspace/toolchains/dart` and Pub packages at
`/workspace/.pub-cache`. There are no application services or required secrets.
The locked development dependencies currently require Dart >=3.13.0; other SDKs
were not validated. Existing checkouts belong to isolated tasks: do not create
Git worktrees unless explicitly requested.

## Repeatable installation

```sh
set -euo pipefail
cd /workspace/quds_lang
bash tool/setup_environment.sh
```

The helper pulls/extracts the pinned official image if the SDK is absent, restores
packages with `dart pub get --enforce-lockfile`, and installs the `quds` executable
from the existing checkout. It does not modify application code or the lockfile.
A managed local Docker daemon is required only to refresh a missing SDK. Registry
access uses the environment's existing package-manager network preset, including
Docker Hub authentication, registry, and blob delivery domains. Pub uses `pub.dev`.
The blocked `storage.googleapis.com` archive route is not required by this method.

On first use in a sandbox, Dart can require approved execution outside the
filesystem sandbox to initialize `/home/agent/.dart-tool` and `.dartServer`.
Keep the real HOME and inherited proxy/CA configuration. The initial initialization
was completed on this instance. Do not disable TLS, checksums, or signature checks.

## Startup instructions for future tasks

No server needs restarting. Activate the SDK and CLI in each shell:

```sh
export PATH="/workspace/toolchains/dart/bin:/workspace/.pub-cache/bin:$PATH"
export PUB_CACHE=/workspace/.pub-cache
cd /workspace/quds_lang
dart --version
```

Read `AGENTS.md` and the relevant documentation before working. If package
configuration or the CLI is missing, rerun the helper. Verify development changes:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze
dart test --reporter expanded
```

For the executable smoke check:

```sh
quds build examples/sum.quds
dart analyze examples/sum.dart
dart examples/sum.dart
```

Expected output: `Total: 60` and `12`, on separate lines. Generated example output
is ignored by Git. The CLI preserves non-generated files and reports overwrite
conflicts rather than destroying them.

## Configuration persistence

The running instance and helper were prepared and validated. Attempts to read or
save the environment configuration draft returned `INVALID_ARGUMENT`; the save
response said persistence could not be confirmed. Neither `install_script` nor
`start_skill` is confirmed saved, and no network addition is confirmed saved.
The complete installation and startup instructions are retained above for the
environment settings. Publication and restoration in a new task have not been
performed or validated. Runtime readiness does not establish draft persistence.
