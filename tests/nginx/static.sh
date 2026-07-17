#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)

find "$ROOT/nginx" -type f \( -name '*.sh' -o -name '*.envsh' \) -print | while IFS= read -r script; do
  sh -n "$script"
done

grep -q 'nginx:1.30.4-alpine-slim@sha256:ddde39c6' "$ROOT/nginx/base/Dockerfile"
grep -q 'ARG BUILD_VERSION=2.0.0' "$ROOT/nginx/base/Dockerfile"
grep -q 'ARG BUILD_VERSION=2.0.0' "$ROOT/nginx/core/Dockerfile"
grep -q 'NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1' "$ROOT/nginx/core/Dockerfile"
grep -q 'ARG BUILD_VERSION=2.0.0' "$ROOT/nginx/cdn/Dockerfile"
grep -q 'ARG BUILD_VERSION=1.0.0' "$ROOT/nginx/spa/Dockerfile"
grep -q 'parent: nginx-cdn' "$ROOT/catalog/images.yaml"

for dockerfile in base core cdn spa; do
  grep -q "nginx/$dockerfile/Dockerfile" "$ROOT/.github/workflows/publish-container.yml"
done
grep -q 'ghcr.io/hadolint/hadolint:v2.14.0-debian@sha256:' "$ROOT/.github/workflows/publish-container.yml"
grep -q 'hadolint nginx/base/Dockerfile nginx/core/Dockerfile nginx/cdn/Dockerfile nginx/spa/Dockerfile' "$ROOT/.github/workflows/publish-container.yml"
grep -q 'docker.io/rhysd/actionlint:1.7.7@sha256:' "$ROOT/.github/workflows/publish-container.yml"
grep -q 'docker.io/aquasec/trivy:0.67.2@sha256:' "$ROOT/.github/workflows/publish-container.yml"
if grep -q 'hadolint/hadolint-action' "$ROOT/.github/workflows/publish-container.yml"; then
  echo >&2 'Hadolint wrapper action must not replace the explicit scoped lint command'
  exit 1
fi

if grep -R -nE 'ghcr\.io/gecut/nginx/(base|core):latest|nginx:1\.28\.2' "$ROOT/nginx"; then
  echo >&2 'Mutable or obsolete NGINX parent reference found'
  exit 1
fi

if grep -Eq '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+[^#[:space:]]+@v' "$ROOT/.github/workflows/publish-container.yml"; then
  echo >&2 'Mutable GitHub Action reference found in publish-container.yml'
  exit 1
fi

if grep -Fq "print \$2; exit" "$ROOT/.github/workflows/publish-container.yml"; then
  echo >&2 'Digest extraction must consume the complete Buildx output under pipefail'
  exit 1
fi

echo 'Static NGINX checks passed'
