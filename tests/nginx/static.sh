#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)

find "$ROOT/nginx" -type f \( -name '*.sh' -o -name '*.envsh' \) -print | while IFS= read -r script; do
  sh -n "$script"
done

grep -q 'nginx:1.30.4-alpine-slim@sha256:ddde39c6' "$ROOT/nginx/base/Dockerfile"
grep -q 'ARG BUILD_VERSION=2.0.0' "$ROOT/nginx/base/Dockerfile"
grep -q 'ARG BUILD_VERSION=2.0.0' "$ROOT/nginx/core/Dockerfile"
grep -q 'ARG BUILD_VERSION=2.0.0' "$ROOT/nginx/cdn/Dockerfile"
grep -q 'ARG BUILD_VERSION=1.0.0' "$ROOT/nginx/spa/Dockerfile"
grep -q 'parent: nginx-cdn' "$ROOT/catalog/images.yaml"

if grep -R -nE 'ghcr\.io/gecut/nginx/(base|core):latest|nginx:1\.28\.2' "$ROOT/nginx"; then
  echo >&2 'Mutable or obsolete NGINX parent reference found'
  exit 1
fi

echo 'Static NGINX checks passed'
