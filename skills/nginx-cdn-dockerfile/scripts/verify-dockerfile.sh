#!/bin/sh
set -eu

file=${1:-Dockerfile}
[ -f "$file" ] || { echo >&2 "verify-dockerfile.sh: missing $file"; exit 2; }

fail() { echo >&2 "verify-dockerfile.sh: FAIL: $1"; exit 1; }
pass() { echo "verify-dockerfile.sh: PASS: $1"; }

grep -Eq '^FROM ghcr\.io/gecut/nginx/cdn:[0-9]+\.[0-9]+\.[0-9]+([[:space:]]|$)' "$file" ||
  fail "final image is not a SemVer-pinned nginx-cdn image"
grep -Eq '^ARG NODE_VERSION=[0-9]+\.[0-9]+\.[0-9]+-' "$file" ||
  fail "Node builder must use a full SemVer base tag"
grep -Eq '^ARG PNPM_VERSION=[0-9]+\.[0-9]+\.[0-9]+$|corepack prepare.*pnpm@[0-9]+\.[0-9]+\.[0-9]+' "$file" ||
  fail "pnpm must use a full SemVer version"
grep -Eq 'COPY --from=.*--chown=nginx:nginx .* /data/' "$file" ||
  fail "runtime artifact must be copied with nginx ownership"
grep -q 'NGINX_GZIP=off' "$file" || fail "gzip must be disabled"
grep -q 'NGINX_GZIP_STATIC=off' "$file" || fail "gzip-static must be disabled"
grep -q 'NGINX_GZIP_VARY=off' "$file" || fail "gzip Vary must be disabled"
grep -q 'NGINX_EXPIRES_DYNAMIC=off' "$file" || fail "dynamic expires must be disabled"
grep -q 'NGINX_EXPIRES_STATIC=off' "$file" || fail "static expires must be disabled"
grep -q 'NGINX_EXPIRES_DEFAULT=off' "$file" || fail "default expires must be disabled"
grep -Eq 'HEALTHCHECK|server-info' "$file" || fail "health contract is not documented"
if grep -Eq ':[[:space:]]*latest([[:space:]]|$)|@sha256:' "$file"; then
  fail "consumer Dockerfile contains latest or digest syntax"
fi
pass "SemVer images, build stages, runtime policy, ownership, and health contract"
