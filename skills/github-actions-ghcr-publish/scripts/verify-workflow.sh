#!/bin/sh
set -eu

file=${1:-.github/workflows/deploy-image.yml}
[ -f "$file" ] || { echo >&2 "verify-workflow.sh: missing $file"; exit 2; }

fail() { echo >&2 "verify-workflow.sh: FAIL: $1"; exit 1; }
pass() { echo "verify-workflow.sh: PASS: $1"; }

grep -Eq '^on:' "$file" || fail "workflow has no on declaration"
grep -q 'pull_request' "$file" || fail "workflow has no pull_request validation"
grep -q 'workflow_dispatch' "$file" || fail "workflow has no manual dispatch"
grep -q 'packages: write' "$file" || fail "workflow has no scoped GHCR permission"
grep -q 'setup-buildx-action@[0-9]' "$file" || fail "workflow has no Buildx setup"
grep -Eq 'build-push-action@[0-9]|buildx build' "$file" || fail "workflow has no image build"
grep -Eq 'cache-from: type=gha|--cache-from type=gha' "$file" || fail "workflow has no GHA cache-from"
grep -Eq 'cache-to: type=gha|--cache-to type=gha' "$file" || fail "workflow has no GHA cache-to"
if grep -Eq 'uses:.*(@sha256:|@[0-9a-f]{40}|@v[0-9]+$)' "$file"; then
  fail "workflow contains SHA or major-only action reference"
fi
if grep -Eq 'uses:.*@(latest|main|master)([[:space:]]|$)' "$file"; then
  fail "workflow contains mutable action reference"
fi
pass "workflow events, permissions, Buildx, cache, and SemVer action references"
