#!/usr/bin/env bash
set -euo pipefail
# Run from an existing checkout; cloud tasks are already isolated.
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
sdk_dir=/workspace/toolchains/dart
image=dart@sha256:854f3c50b1cbd4a5a54c9fa67d4f5b6702ac49b4a26d21a80e7712a72528b215
if [[ ! -x "$sdk_dir/bin/dart" ]]; then
  mkdir -p /workspace/toolchains
  docker_local() {
    env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS \
      -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH \
      docker --host=unix:///var/run/docker.sock "$@"
  }
  docker_local info >/dev/null
  docker_local pull "$image"
  extract_dir="$(mktemp -d /workspace/toolchains/quds-sdk-XXXXXX)"
  container_id="$(docker_local create "$image")"
  trap 'docker_local rm "$container_id" >/dev/null; rm -rf -- "$extract_dir"' EXIT
  docker_local cp "$container_id:/usr/lib/dart" "$extract_dir/dart"
  mv -- "$extract_dir/dart" "$sdk_dir"
fi
export PATH="$sdk_dir/bin:$PATH"
export PUB_CACHE="${PUB_CACHE:-/workspace/.pub-cache}"
dart --version
cd "$repo_dir"
dart pub get --enforce-lockfile
dart pub global activate --source path "$repo_dir"
echo 'Activate: export PATH="/workspace/toolchains/dart/bin:/workspace/.pub-cache/bin:$PATH"'
echo 'Activate: export PUB_CACHE=/workspace/.pub-cache'
