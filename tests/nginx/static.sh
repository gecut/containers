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

for variable in NGINX_BASE_VERSION NGINX_CORE_VERSION NGINX_CDN_VERSION NGINX_SPA_VERSION; do
  version=$(sed -n "s/^[[:space:]]*$variable:[[:space:]]*//p" "$ROOT/.github/workflows/publish-container.yml")
  printf '%s\n' "$version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' || {
    echo >&2 "$variable must use major.minor.patch"
    exit 1
  }
done

grep -q "major_tag=\${version%%.*}" "$ROOT/.github/workflows/publish-container.yml"
grep -q "minor_tag=\${version%.*}" "$ROOT/.github/workflows/publish-container.yml"
grep -q -- "-t \"\$repository:\$patch_tag\"" "$ROOT/.github/workflows/publish-container.yml"
grep -q -- "-t \"\$repository:\$minor_tag\"" "$ROOT/.github/workflows/publish-container.yml"
grep -q -- "-t \"\$repository:\$major_tag\"" "$ROOT/.github/workflows/publish-container.yml"
grep -q 'Preflight immutable SHA tags' "$ROOT/.github/workflows/publish-container.yml"
grep -q 'Existing version tags will be replaced; SHA tags remain immutable' "$ROOT/.github/workflows/publish-container.yml"
grep -q 'already points to the candidate digest' "$ROOT/.github/workflows/publish-container.yml"
if grep -q 'immutable tags are never overwritten\|ALLOW_VERSION_OVERWRITE\|allow_version_overwrite' "$ROOT/.github/workflows/publish-container.yml"; then
  echo >&2 'Version tags must be promoted without a manual overwrite gate'
  exit 1
fi

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
