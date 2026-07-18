#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  verify-origin.sh --origin URL --hashed PATH --html PATH --json PATH \
    --service-worker PATH [--missing PATH] [--image PATH] [policy options]

Read-only checks for a running gecut/nginx/cdn origin. Required fixture paths
must already exist. PATH values begin with '/'. The script checks:
  - successful fixture responses;
  - immutable hashed-asset caching, ETag, and conditional 304;
  - HTML revalidation and s-maxage=0;
  - short JSON/manifest caching;
  - service-worker no-cache;
  - missing-asset 404 with no-store;
  - exactly one Cache-Control and Vary field;
  - Accept plus Accept-Encoding Vary tokens for --image, when supplied.

Policy options default to the stock image values and can be changed when the
origin intentionally overrides cache TTLs:
  --hashed-max-age SECONDS    default: 31536000
  --hashed-s-maxage SECONDS  default: 31536000
  --html-max-age SECONDS      default: 0
  --html-s-maxage SECONDS     default: 0
  --json-max-age SECONDS      default: 60

Example:
  verify-origin.sh \
    --origin http://127.0.0.1:8080 \
    --hashed /assets/app-C6uTJdX2.js \
    --html / \
    --json /manifest.webmanifest \
    --service-worker /service-worker.js \
    --image /images/photo.jpg

The script sends HEAD requests plus one conditional GET. It never writes to the
origin. It requires curl, awk, grep, mktemp, and standard POSIX utilities.
EOF
}

origin=
hashed=
html=
json=
service_worker=
missing=/__nginx_cdn_verify_missing__.js
image=
hashed_max_age=31536000
hashed_s_maxage=31536000
html_max_age=0
html_s_maxage=0
json_max_age=60

while [ "$#" -gt 0 ]; do
  case "$1" in
    --origin|--hashed|--html|--json|--service-worker|--missing|--image|--hashed-max-age|--hashed-s-maxage|--html-max-age|--html-s-maxage|--json-max-age)
      [ "$#" -ge 2 ] || { echo >&2 "verify-origin.sh: $1 requires a value"; exit 2; }
      case "$1" in
        --origin) origin=$2 ;;
        --hashed) hashed=$2 ;;
        --html) html=$2 ;;
        --json) json=$2 ;;
        --service-worker) service_worker=$2 ;;
        --missing) missing=$2 ;;
        --image) image=$2 ;;
        --hashed-max-age) hashed_max_age=$2 ;;
        --hashed-s-maxage) hashed_s_maxage=$2 ;;
        --html-max-age) html_max_age=$2 ;;
        --html-s-maxage) html_s_maxage=$2 ;;
        --json-max-age) json_max_age=$2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo >&2 "verify-origin.sh: unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

for command in curl awk grep mktemp; do
  command -v "$command" >/dev/null 2>&1 || {
    echo >&2 "verify-origin.sh: required command not found: $command"
    exit 2
  }
done

[ -n "$origin" ] || { echo >&2 'verify-origin.sh: --origin is required'; exit 2; }
case "$origin" in http://*|https://*) ;; *) echo >&2 'verify-origin.sh: --origin must use http:// or https://'; exit 2 ;; esac
origin=${origin%/}

for pair in "--hashed:$hashed" "--html:$html" "--json:$json" "--service-worker:$service_worker" "--missing:$missing"; do
  option=${pair%%:*}
  path=${pair#*:}
  [ -n "$path" ] || { echo >&2 "verify-origin.sh: $option is required"; exit 2; }
  case "$path" in /*) ;; *) echo >&2 "verify-origin.sh: $option must begin with /"; exit 2 ;; esac
done
if [ -n "$image" ]; then
  case "$image" in /*) ;; *) echo >&2 'verify-origin.sh: --image must begin with /'; exit 2 ;; esac
fi
for value in "$hashed_max_age" "$hashed_s_maxage" "$html_max_age" "$html_s_maxage" "$json_max_age"; do
  case "$value" in ''|*[!0-9]*) echo >&2 'verify-origin.sh: policy ages must be unsigned integers'; exit 2 ;; esac
done

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/nginx-cdn-verify.XXXXXX")
trap 'rm -rf "$tmpdir"' 0 HUP INT TERM
headers=$tmpdir/headers
body=$tmpdir/body

fail() {
  echo >&2 "verify-origin.sh: FAIL: $1"
  exit 1
}

pass() {
  echo "verify-origin.sh: PASS: $1"
}

header_value() {
  name=$1
  awk -v wanted="$name" '
    BEGIN { wanted = tolower(wanted) }
    {
      line = $0
      sub(/\r$/, "", line)
      separator = index(line, ":")
      if (separator > 0 && tolower(substr(line, 1, separator - 1)) == wanted) {
        value = substr(line, separator + 1)
        sub(/^[[:space:]]+/, "", value)
        print value
        exit
      }
    }
  ' "$headers"
}

header_count() {
  name=$1
  awk -v wanted="$name" '
    BEGIN { wanted = tolower(wanted); count = 0 }
    {
      separator = index($0, ":")
      if (separator > 0 && tolower(substr($0, 1, separator - 1)) == wanted) count++
    }
    END { print count }
  ' "$headers"
}

fetch_head() {
  path=$1
  shift
  : > "$headers"
  status=$(curl -sS --connect-timeout 5 --max-time 15 -I -D "$headers" -o /dev/null -w '%{http_code}' "$@" "$origin$path") ||
    fail "request failed: $origin$path"
}

assert_status() {
  expected=$1
  label=$2
  [ "$status" = "$expected" ] || fail "$label returned $status, expected $expected"
}

assert_one_header() {
  name=$1
  label=$2
  count=$(header_count "$name")
  [ "$count" = 1 ] || fail "$label returned $count $name fields, expected 1"
}

assert_header_token() {
  name=$1
  token=$2
  label=$3
  value=$(header_value "$name")
  [ -n "$value" ] || fail "$label is missing $name"
  printf '%s\n' "$value" | tr ',' '\n' | awk '{ sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' | grep -iFx -e "$token" >/dev/null ||
    fail "$label $name does not contain the exact token '$token': $value"
}

fetch_head "$hashed"
assert_status 200 'hashed fixture'
assert_one_header Cache-Control 'hashed fixture'
assert_one_header Vary 'hashed fixture'
assert_header_token Cache-Control immutable 'hashed fixture'
assert_header_token Cache-Control "max-age=$hashed_max_age" 'hashed fixture'
assert_header_token Cache-Control "s-maxage=$hashed_s_maxage" 'hashed fixture'
assert_header_token Vary Accept-Encoding 'hashed fixture'
etag=$(header_value ETag)
[ -n "$etag" ] || fail 'hashed fixture is missing ETag'
: > "$headers"
: > "$body"
status=$(curl -sS --connect-timeout 5 --max-time 15 -D "$headers" -o "$body" -w '%{http_code}' -H "If-None-Match: $etag" "$origin$hashed") ||
  fail 'conditional hashed request failed'
assert_status 304 'conditional hashed fixture'
pass 'hashed cache policy, ETag, Vary, and conditional 304'

fetch_head "$html"
assert_status 200 'HTML fixture'
assert_one_header Cache-Control 'HTML fixture'
assert_one_header Vary 'HTML fixture'
assert_header_token Cache-Control "max-age=$html_max_age" 'HTML fixture'
assert_header_token Cache-Control must-revalidate 'HTML fixture'
assert_header_token Cache-Control "s-maxage=$html_s_maxage" 'HTML fixture'
pass 'HTML revalidation policy'

fetch_head "$json"
assert_status 200 'JSON fixture'
assert_one_header Cache-Control 'JSON fixture'
assert_one_header Vary 'JSON fixture'
assert_header_token Cache-Control "max-age=$json_max_age" 'JSON fixture'
pass 'JSON/manifest short-cache policy'

fetch_head "$service_worker"
assert_status 200 'service-worker fixture'
assert_one_header Cache-Control 'service-worker fixture'
assert_one_header Vary 'service-worker fixture'
assert_header_token Cache-Control no-cache 'service-worker fixture'
pass 'service-worker revalidation policy'

fetch_head "$missing"
assert_status 404 'missing fixture'
assert_one_header Cache-Control 'missing fixture'
assert_one_header Vary 'missing fixture'
assert_header_token Cache-Control no-store 'missing fixture'
pass '404 no-store policy'

if [ -n "$image" ]; then
  fetch_head "$image" -H 'Accept: image/webp'
  assert_status 200 'image fixture'
  assert_one_header Cache-Control 'image fixture'
  assert_one_header Vary 'image fixture'
  assert_header_token Vary Accept 'image fixture'
  assert_header_token Vary Accept-Encoding 'image fixture'
  pass 'image representation Vary policy'
fi

echo 'verify-origin.sh: all checks passed'
