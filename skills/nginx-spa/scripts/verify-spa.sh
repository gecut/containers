#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: verify-spa.sh [options] BASE_URL

Read-only HTTP checks for a running ghcr.io/gecut/nginx/spa origin.

Options:
  --shell-path PATH      Shell URI (default: /index.html)
  --asset PATH           Existing hashed asset URI to verify
  --deep-route PATH      Missing extensionless route (default: /__spa_verify/deep/route)
  --missing-asset PATH   Missing known asset URI (default: /__spa_verify/missing.js)
  --dotted-route PATH    Missing dotted application URI (default: /__spa_verify/account.settings)
  --check-post           Opt in to a POST safety check against --deep-route
  -h, --help             Show this help

The verifier sends only HEAD requests by default. `--check-post` sends a POST
request and must be used only against a disposable or known-static origin.
EOF
}

fail_count=0
shell_path=/index.html
deep_route=/__spa_verify/deep/route
missing_asset=/__spa_verify/missing.js
dotted_route=/__spa_verify/account.settings
asset_path=
check_post=off

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  fail_count=$((fail_count + 1))
}

pass() {
  printf 'PASS: %s\n' "$*"
}

require_path() {
  case "$2" in
    /*) ;;
    *) printf 'ERROR: %s must start with /\n' "$1" >&2; exit 2 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --shell-path|--asset|--deep-route|--missing-asset|--dotted-route)
      [ "$#" -ge 2 ] || { printf 'ERROR: %s requires a value\n' "$1" >&2; exit 2; }
      option=$1
      value=$2
      require_path "$option" "$value"
      case "$option" in
        --shell-path) shell_path=$value ;;
        --asset) asset_path=$value ;;
        --deep-route) deep_route=$value ;;
        --missing-asset) missing_asset=$value ;;
        --dotted-route) dotted_route=$value ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    --check-post) check_post=on; shift ;;
    --*) printf 'ERROR: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *)
      [ -z "${base_url:-}" ] || { printf 'ERROR: only one BASE_URL is allowed\n' >&2; exit 2; }
      base_url=$1
      shift
      ;;
  esac
done

[ -n "${base_url:-}" ] || { usage >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { printf 'ERROR: curl is required\n' >&2; exit 2; }
base_url=${base_url%/}
case "$base_url" in http://*|https://*) ;; *) printf 'ERROR: BASE_URL must use http:// or https://\n' >&2; exit 2 ;; esac

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/verify-spa.XXXXXX")
trap 'rm -rf "$tmp_dir"' 0 HUP INT TERM

request() {
  name=$1
  method=$2
  path=$3
  header_file="$tmp_dir/$name.headers"
  case "$method" in
    HEAD)
      curl -sS --connect-timeout 5 --max-time 15 --head -o /dev/null -D "$header_file" \
        -w '%{http_code}' "$base_url$path"
      ;;
    *)
      curl -sS --connect-timeout 5 --max-time 15 -X "$method" -o /dev/null -D "$header_file" \
        -w '%{http_code}' "$base_url$path"
      ;;
  esac
}

header_value() {
  name=$1
  field=$2
  awk -v field="$field" '
    tolower(substr($0, 1, length(field) + 1)) == tolower(field ":") {
      sub("^[^:]*:[[:space:]]*", "")
      sub("\\r$", "")
      value=$0
    }
    END { print value }
  ' "$tmp_dir/$name.headers"
}

expect_status() {
  name=$1
  actual=$2
  expected=$3
  if [ "$actual" = "$expected" ]; then pass "$name returned $expected"; else fail "$name returned $actual, expected $expected"; fi
}

expect_header_contains() {
  name=$1
  field=$2
  expected=$3
  value=$(header_value "$name" "$field")
  case "$value" in
    *"$expected"*) pass "$name has $field containing $expected" ;;
    *) fail "$name $field is '${value:-<missing>}', expected to contain $expected" ;;
  esac
}

expect_header_token() {
  name=$1
  field=$2
  expected=$3
  value=$(header_value "$name" "$field")
  if printf '%s\n' "$value" | tr ',' '\n' | awk '{ sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' | grep -iFx -e "$expected" >/dev/null; then
    pass "$name has $field token $expected"
  else
    fail "$name $field is '${value:-<missing>}', expected exact token $expected"
  fi
}

expect_single_header() {
  name=$1
  field=$2
  count=$(awk -v field="$field" '
    tolower(substr($0, 1, length(field) + 1)) == tolower(field ":") { count++ }
    END { print count + 0 }
  ' "$tmp_dir/$name.headers")
  if [ "$count" -eq 1 ]; then
    pass "$name has one $field field"
  else
    fail "$name has $count $field fields, expected exactly one"
  fi
}

shell_status=$(request shell HEAD "$shell_path") || { fail "shell request failed"; shell_status=000; }
expect_status shell "$shell_status" 200
expect_single_header shell Cache-Control
expect_header_token shell Cache-Control max-age=0
expect_header_token shell Cache-Control s-maxage=0
expect_header_token shell Cache-Control must-revalidate
expect_header_contains shell ETag '"'
expect_single_header shell Vary
expect_header_token shell Vary Accept-Encoding
expect_header_contains shell X-Frame-Options SAMEORIGIN
expect_header_contains shell X-Content-Type-Options nosniff
expect_header_contains shell Referrer-Policy strict-origin-when-cross-origin

if [ -n "$asset_path" ]; then
  existing_asset_status=$(request existing_asset HEAD "$asset_path") || { fail "existing-asset request failed"; existing_asset_status=000; }
  expect_status existing_asset "$existing_asset_status" 200
  expect_header_token existing_asset Cache-Control immutable
  expect_header_contains existing_asset ETag '"'
  expect_header_token existing_asset Vary Accept-Encoding
  expect_header_contains existing_asset X-Content-Type-Options nosniff
fi

deep_status=$(request deep HEAD "$deep_route") || { fail "deep-route request failed"; deep_status=000; }
expect_status deep "$deep_status" 200
expect_single_header deep Cache-Control
expect_header_token deep Cache-Control max-age=0
expect_header_token deep Cache-Control s-maxage=0
expect_header_token deep Cache-Control must-revalidate
expect_header_contains deep ETag '"'
expect_single_header deep Vary
expect_header_token deep Vary Accept-Encoding
expect_header_contains deep X-Content-Type-Options nosniff
shell_etag=$(header_value shell ETag)
deep_etag=$(header_value deep ETag)
if [ -n "$shell_etag" ] && [ "$deep_etag" = "$shell_etag" ]; then
  pass "deep route resolves to the configured shell representation"
else
  fail "deep route ETag '${deep_etag:-<missing>}' differs from shell ETag '${shell_etag:-<missing>}'"
fi

asset_status=$(request asset HEAD "$missing_asset") || { fail "missing-asset request failed"; asset_status=000; }
expect_status asset "$asset_status" 404
expect_header_token asset Cache-Control no-store

dotted_status=$(request dotted HEAD "$dotted_route") || { fail "dotted-route request failed"; dotted_status=000; }
expect_status dotted "$dotted_status" 404
expect_header_token dotted Cache-Control no-store

if [ "$check_post" = on ]; then
  post_status=$(request post POST "$deep_route") || { fail "POST request failed"; post_status=000; }
  case "$post_status" in
    200) fail "POST deep route returned shell-like status 200" ;;
    000) ;;
    *) pass "POST deep route did not return shell status (got $post_status)" ;;
  esac
  expect_header_token post Cache-Control no-store
fi

if [ "$fail_count" -ne 0 ]; then
  printf '\n%d verification check(s) failed.\n' "$fail_count" >&2
  exit 1
fi

printf '\nAll SPA origin checks passed.\n'
