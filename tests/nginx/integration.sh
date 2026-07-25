#!/bin/sh
set -eu

: "${NGINX_BASE_IMAGE:=local/nginx/base:test}"
: "${NGINX_CORE_IMAGE:=local/nginx/core:test}"
: "${NGINX_CDN_IMAGE:=local/nginx/cdn:test}"
: "${NGINX_SPA_IMAGE:=local/nginx/spa:test}"

WORK=$(mktemp -d)
containers=""
STARTED_PORT=""

cleanup() {
  for container in $containers; do
    docker rm -f "$container" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo >&2 "integration.sh: $1"
  exit 1
}

note() {
  echo "integration.sh: $1"
}

start() {
  name=$1
  image=$2
  shift 2
  if ! docker run -d --name "$name" -p 127.0.0.1::80 "$@" "$image" >/dev/null; then
    fail "could not start $name from $image"
  fi
  containers="$containers $name"
  port=$(docker port "$name" 80/tcp | sed -n '1s/.*://p')
  [ -n "$port" ] || { docker logs "$name" >&2; fail "could not discover the published port for $name"; }
  i=0
  until curl -fsS "http://127.0.0.1:$port/server-info" >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -lt 30 ] || { docker logs "$name" >&2; fail "$name did not become ready"; }
    sleep 1
  done
  STARTED_PORT=$port
}

assert_status() {
  expected=$1
  url=$2
  actual=$(curl -sS -o /dev/null -w '%{http_code}' "$url")
  [ "$actual" = "$expected" ] || fail "$url returned $actual, expected $expected"
}

assert_header() {
  url=$1
  name=$2
  pattern=$3
  curl -sSI "$url" | grep -Eiq "^${name}:.*${pattern}" || fail "$url is missing $name matching $pattern"
}

assert_no_header() {
  url=$1
  name=$2
  shift 2
  curl -sSI "$@" "$url" | grep -Eiq "^${name}:" && fail "$url unexpectedly returned $name"
  return 0
}

note 'checking base validation and worker autotune'
docker run --rm "$NGINX_BASE_IMAGE" nginx -t >/dev/null
docker run --rm -e NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=off "$NGINX_BASE_IMAGE" nginx -t >/dev/null 2>&1 && fail 'invalid worker autotune value was accepted'
docker run --rm -e NGINX_OPEN_FILE_CACHE_ERRORS=invalid "$NGINX_CORE_IMAGE" nginx -t >/dev/null 2>&1 && fail 'invalid open-file cache errors value was accepted'

note 'checking core resolver and real-IP contracts'
if ! core_config=$(docker run --rm "$NGINX_CORE_IMAGE" nginx -T 2>&1); then
  printf '%s\n' "$core_config" >&2
  fail 'default core configuration did not validate'
fi
printf '%s' "$core_config" | grep -q 'set_real_ip_from' && fail 'Real IP rewriting is enabled by default'
printf '%s' "$core_config" | grep -Eq '^resolver ' && fail 'Resolver is enabled by default'
if ! local_resolver_config=$(docker run --rm -e NGINX_RESOLVERS=local "$NGINX_CORE_IMAGE" nginx -T 2>&1); then
  printf '%s\n' "$local_resolver_config" >&2
  fail 'local resolver configuration did not validate'
fi
printf '%s' "$local_resolver_config" | grep -Eq '^resolver ' || fail 'local resolver was not rendered'
if ! explicit_resolver_config=$(docker run --rm -e 'NGINX_RESOLVERS=1.1.1.1 8.8.8.8' "$NGINX_CORE_IMAGE" nginx -T 2>&1); then
  printf '%s\n' "$explicit_resolver_config" >&2
  fail 'explicit resolver configuration did not validate'
fi
printf '%s' "$explicit_resolver_config" | grep -q '^resolver 1.1.1.1 8.8.8.8 ' || fail 'explicit resolvers were not rendered'
if ! real_ip_config=$(docker run --rm -e NGINX_TRUSTED_PROXY_CIDRS=10.0.0.0/8 "$NGINX_CORE_IMAGE" nginx -T 2>&1); then
  printf '%s\n' "$real_ip_config" >&2
  fail 'explicit real-IP configuration did not validate'
fi
printf '%s' "$real_ip_config" | grep -q 'set_real_ip_from 10.0.0.0/8' || fail 'trusted proxy CIDR was not rendered'
docker run --rm -e NGINX_TRUSTED_PROXY_CIDRS=10.0.0.1 "$NGINX_CORE_IMAGE" nginx -t >/dev/null 2>&1 && fail 'Non-CIDR trusted proxy was accepted'

note 'checking core static routing and security'
mkdir -p "$WORK/core/.well-known"
printf '%s\n' '<h1>core</h1>' > "$WORK/core/index.html"
printf '%s\n' 'association' > "$WORK/core/.well-known/assetlinks.json"
start nginx-core-test "$NGINX_CORE_IMAGE" -v "$WORK/core:/data:ro"
core_port=$STARTED_PORT
assert_status 200 "http://127.0.0.1:$core_port/"
assert_status 200 "http://127.0.0.1:$core_port/.well-known/assetlinks.json"
assert_status 403 "http://127.0.0.1:$core_port/.env"
core_post_status=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$core_port/")
[ "$core_post_status" = 403 ] || fail "Core POST returned $core_post_status, expected 403"
assert_header "http://127.0.0.1:$core_port/" X-Content-Type-Options nosniff

start nginx-core-robots-test "$NGINX_CORE_IMAGE" -e NGINX_DISALLOW_ROBOTS=on
robots_port=$STARTED_PORT
docker exec nginx-core-robots-test grep -q 'Disallow: /' /data/robots.txt || {
  docker logs nginx-core-robots-test >&2
  fail 'Robots disallow toggle did not install /data/robots.txt'
}
curl -fsS "http://127.0.0.1:$robots_port/robots.txt" | grep -q 'Disallow: /' || fail 'Robots disallow toggle did not replace the bundled default'

mkdir -p "$WORK/custom-robots"
printf '%s\n' 'User-agent: *' 'Allow: /public/' > "$WORK/custom-robots/robots.txt"
start nginx-core-custom-robots-test "$NGINX_CORE_IMAGE" \
  -e NGINX_DISALLOW_ROBOTS=on -v "$WORK/custom-robots:/data:ro"
custom_robots_port=$STARTED_PORT
curl -fsS "http://127.0.0.1:$custom_robots_port/robots.txt" | grep -q 'Allow: /public/' || fail 'Consumer-provided robots.txt was overwritten'

printf '%s\n' 'jpeg' > "$WORK/core/photo.jpg"
printf '%s\n' 'webp' > "$WORK/core/photo.jpg.webp"
start nginx-core-features-test "$NGINX_CORE_IMAGE" \
  -e NGINX_CORS_ENABLE=on -e NGINX_AUTO_WEBP=on -e NGINX_FORCE_DOMAIN=example.test \
  -v "$WORK/core:/data:ro"
features_port=$STARTED_PORT
redirect_headers=$(curl -sSI -H 'Host: wrong.test' "http://127.0.0.1:$features_port/path")
printf '%s' "$redirect_headers" | grep -q '308' || fail 'Canonical host did not return 308'
printf '%s' "$redirect_headers" | grep -Eiq '^Location: https://example\.test/path' || fail 'Canonical redirect did not preserve HTTPS'
options_headers=$(curl -sSI -X OPTIONS -H 'Host: example.test' "http://127.0.0.1:$features_port/")
printf '%s' "$options_headers" | grep -q '204' || fail 'CORS preflight did not return 204'
printf '%s' "$options_headers" | grep -Eiq '^Access-Control-Allow-Origin: \*' || fail 'CORS origin header is missing'
printf '%s' "$options_headers" | grep -Eiq '^X-Content-Type-Options: nosniff' || fail 'Security headers were lost in CORS response'
curl -fsS -H 'Host: example.test' -H 'Accept: image/webp' "http://127.0.0.1:$features_port/photo.jpg" | grep -q webp || fail 'WebP negotiation did not serve the alternate file'
curl -sSI -H 'Host: example.test' -H 'Accept: image/webp' "http://127.0.0.1:$features_port/photo.jpg" | grep -Eiq '^Vary:.*Accept' || fail 'WebP response is missing Vary: Accept'

note 'checking CDN cache profiles and conditional requests'
mkdir -p "$WORK/cdn"
printf '%s\n' '<h1>cdn</h1>' > "$WORK/cdn/index.html"
printf '%s\n' 'vite' > "$WORK/cdn/app-C6uTJdX2.js"
printf '%s\n' 'cra' > "$WORK/cdn/main.abc12345.chunk.js"
printf '%s\n' 'human-js' > "$WORK/cdn/hero-marketing.js"
printf '%s\n' 'uuid-js' > "$WORK/cdn/app-550e8400-e29b-41d4-a716-446655440000.js"
printf '%s\n' 'worker' > "$WORK/cdn/service-worker.js"
printf '%s\n' '{}' > "$WORK/cdn/manifest.webmanifest"
printf '%s\n' 'human' > "$WORK/cdn/hero-marketing.webp"
printf '%s\n' 'uuid' > "$WORK/cdn/550e8400-e29b-41d4-a716-446655440000.png"
printf '%s\n' 'hash-image' > "$WORK/cdn/logo.129fc3.webp"
printf '%s\n' 'avif-image' > "$WORK/cdn/photo-C6uTJdX2.avif"
printf '%s\n' 'jpeg' > "$WORK/cdn/photo.jpg"
printf '%s\n' 'webp' > "$WORK/cdn/photo.jpg.webp"
start nginx-cdn-test "$NGINX_CDN_IMAGE" -v "$WORK/cdn:/data:ro"
cdn_port=$STARTED_PORT
docker run --rm -e NGINX_CDN_IMAGE_S_MAXAGE=invalid "$NGINX_CDN_IMAGE" nginx -t >/dev/null 2>&1 && fail 'invalid image s-maxage was accepted'
docker run --rm -e 'NGINX_CDN_CACHE_IMAGE=public"bad' "$NGINX_CDN_IMAGE" nginx -t >/dev/null 2>&1 && fail 'unsafe image policy was accepted'
assert_header "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js" Cache-Control immutable
assert_header "http://127.0.0.1:$cdn_port/main.abc12345.chunk.js" Cache-Control immutable
assert_header "http://127.0.0.1:$cdn_port/hero-marketing.js" Cache-Control 'max-age=3600'
assert_header "http://127.0.0.1:$cdn_port/app-550e8400-e29b-41d4-a716-446655440000.js" Cache-Control 'max-age=3600'
for image_path in hero-marketing.webp 550e8400-e29b-41d4-a716-446655440000.png logo.129fc3.webp photo-C6uTJdX2.avif; do
  assert_header "http://127.0.0.1:$cdn_port/$image_path" Cache-Control 'max-age=0'
  assert_header "http://127.0.0.1:$cdn_port/$image_path" Cache-Control 's-maxage=86400'
  assert_header "http://127.0.0.1:$cdn_port/$image_path" Cache-Control must-revalidate
done
assert_header "http://127.0.0.1:$cdn_port/service-worker.js" Cache-Control no-cache
assert_header "http://127.0.0.1:$cdn_port/manifest.webmanifest" Cache-Control max-age=60
assert_header "http://127.0.0.1:$cdn_port/" Cache-Control must-revalidate
etag=$(curl -sSI "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js" | awk 'BEGIN { IGNORECASE=1 } /^ETag:/ { sub(/\r$/, "", $2); print $2; exit }')
[ -n "$etag" ] || fail 'CDN response is missing ETag'
etag_status=$(curl -sS -o /dev/null -w '%{http_code}' -H "If-None-Match: $etag" "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js")
[ "$etag_status" = 304 ] || fail "Conditional ETag request returned $etag_status"
last_modified=$(curl -sSI "http://127.0.0.1:$cdn_port/hero-marketing.webp" | sed -n 's/^Last-Modified: //Ip' | tr -d '\r')
[ -n "$last_modified" ] || fail 'CDN image response is missing Last-Modified'
modified_status=$(curl -sS -o /dev/null -w '%{http_code}' -H "If-Modified-Since: $last_modified" "http://127.0.0.1:$cdn_port/hero-marketing.webp")
[ "$modified_status" = 304 ] || fail "Conditional Last-Modified request returned $modified_status"
header_count=$(curl -sSI "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js" | grep -ic '^Cache-Control:' || true)
[ "$header_count" -eq 1 ] || fail "CDN returned $header_count Cache-Control headers"
vary_count=$(curl -sSI "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js" | grep -ic '^Vary:' || true)
[ "$vary_count" -eq 1 ] || fail "CDN returned $vary_count Vary headers"
assert_header "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js" Vary Accept-Encoding
assert_header "http://127.0.0.1:$cdn_port/hero-marketing.webp" Vary Accept-Encoding
assert_header "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js" Cache-Control 'public'
auth_headers=$(curl -sSI -H 'Authorization: Bearer integration-test' "http://127.0.0.1:$cdn_port/app-C6uTJdX2.js")
printf '%s\n' "$auth_headers" | grep -Eiq '^Cache-Control: private, no-store' || fail 'Authorization request was not forced to private, no-store'
assert_status 404 "http://127.0.0.1:$cdn_port/missing.js"
assert_header "http://127.0.0.1:$cdn_port/missing.js" Cache-Control no-store
assert_header "http://127.0.0.1:$cdn_port/missing.js" X-Content-Type-Options nosniff
"$(dirname "$0")/../../skills/nginx-cdn/scripts/verify-origin.sh" \
  --origin "http://127.0.0.1:$cdn_port" \
  --hashed /app-C6uTJdX2.js \
  --html / \
  --json /manifest.webmanifest \
  --service-worker /service-worker.js \
  --missing /missing.js \
  --image /hero-marketing.webp

note 'checking conditional CDN Vary behavior'
start nginx-cdn-no-vary-test "$NGINX_CDN_IMAGE" \
  -e NGINX_GZIP=off -e NGINX_GZIP_STATIC=off -e NGINX_AUTO_WEBP=off \
  -v "$WORK/cdn:/data:ro"
no_vary_port=$STARTED_PORT
assert_no_header "http://127.0.0.1:$no_vary_port/app-C6uTJdX2.js" Vary
assert_no_header "http://127.0.0.1:$no_vary_port/photo.jpg" Vary

start nginx-cdn-webp-vary-test "$NGINX_CDN_IMAGE" \
  -e NGINX_GZIP=off -e NGINX_GZIP_STATIC=off -e NGINX_AUTO_WEBP=on \
  -v "$WORK/cdn:/data:ro"
webp_vary_port=$STARTED_PORT
assert_no_header "http://127.0.0.1:$webp_vary_port/app-C6uTJdX2.js" Vary
webp_vary=$(curl -sSI -H 'Accept: image/webp' "http://127.0.0.1:$webp_vary_port/photo.jpg" | sed -n 's/^Vary: //Ip' | tr -d '\r')
[ "$webp_vary" = "Accept" ] || fail "WebP-only Vary was '$webp_vary', expected Accept"

start nginx-cdn-both-vary-test "$NGINX_CDN_IMAGE" \
  -e NGINX_AUTO_WEBP=on -v "$WORK/cdn:/data:ro"
both_vary_port=$STARTED_PORT
both_vary=$(curl -sSI -H 'Accept: image/webp' "http://127.0.0.1:$both_vary_port/photo.jpg" | sed -n 's/^Vary: //Ip' | tr -d '\r')
[ "$both_vary" = "Accept, Accept-Encoding" ] || fail "Combined Vary was '$both_vary'"

start nginx-cdn-static-gzip-vary-test "$NGINX_CDN_IMAGE" \
  -e NGINX_GZIP=off -e NGINX_GZIP_STATIC=on -e NGINX_AUTO_WEBP=off \
  -v "$WORK/cdn:/data:ro"
static_gzip_port=$STARTED_PORT
assert_header "http://127.0.0.1:$static_gzip_port/app-C6uTJdX2.js" Vary Accept-Encoding

note 'checking mutable upload visibility and ETag refresh'
mkdir -p "$WORK/mutable-cdn"
start nginx-cdn-mutable-test "$NGINX_CDN_IMAGE" -v "$WORK/mutable-cdn:/data"
mutable_cdn_port=$STARTED_PORT
assert_status 404 "http://127.0.0.1:$mutable_cdn_port/upload.webp"
printf '%s\n' 'first-image-version' > "$WORK/mutable-cdn/upload.webp"
i=0
until [ "$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$mutable_cdn_port/upload.webp")" = 200 ]; do
  i=$((i + 1))
  [ "$i" -lt 20 ] || fail 'New upload remained negatively cached'
  sleep 0.1
done
first_etag=$(curl -sSI "http://127.0.0.1:$mutable_cdn_port/upload.webp" | sed -n 's/^ETag: //Ip' | tr -d '\r')
sleep 1
printf '%s\n' 'second-image-version-with-new-bytes' > "$WORK/mutable-cdn/upload.webp"
i=0
second_etag=$first_etag
while [ "$second_etag" = "$first_etag" ]; do
  i=$((i + 1))
  [ "$i" -lt 20 ] || fail 'Overwritten upload retained its previous ETag'
  sleep 0.1
  second_etag=$(curl -sSI "http://127.0.0.1:$mutable_cdn_port/upload.webp" | sed -n 's/^ETag: //Ip' | tr -d '\r')
done

note 'checking SPA routing, strict asset 404, and shell validation'
mkdir -p "$WORK/spa/assets"
printf '%s\n' 'SPA-SHELL' > "$WORK/spa/index.html"
printf '%s\n' 'asset' > "$WORK/spa/assets/app.abcdef12.js"
printf '%s\n' 'worker' > "$WORK/spa/sw.js"
start nginx-spa-test "$NGINX_SPA_IMAGE" -v "$WORK/spa:/data:ro"
spa_port=$STARTED_PORT
curl -fsS "http://127.0.0.1:$spa_port/users/42?tab=profile" | grep -q SPA-SHELL || fail 'SPA deep route did not return the shell'
assert_status 200 "http://127.0.0.1:$spa_port/assets/app.abcdef12.js"
assert_status 404 "http://127.0.0.1:$spa_port/assets/missing.js"
assert_status 404 "http://127.0.0.1:$spa_port/unknown.route"
assert_header "http://127.0.0.1:$spa_port/assets/missing.js" Cache-Control no-store
assert_header "http://127.0.0.1:$spa_port/users/42" Cache-Control must-revalidate
assert_header "http://127.0.0.1:$spa_port/users/42" X-Content-Type-Options nosniff
post_status=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$spa_port/users/42")
[ "$post_status" = 403 ] || fail "SPA POST returned $post_status, expected 403"
"$(dirname "$0")/../../skills/nginx-spa/scripts/verify-spa.sh" \
  --check-post \
  --asset /assets/app.abcdef12.js \
  --deep-route /users/42 \
  --missing-asset /assets/missing.js \
  --dotted-route /unknown.route \
  "http://127.0.0.1:$spa_port"

mkdir -p "$WORK/empty"
docker run --rm -v "$WORK/empty:/data:ro" "$NGINX_SPA_IMAGE" nginx -t >/dev/null 2>&1 && fail 'SPA started without a shell'

docker kill --signal=QUIT nginx-spa-test >/dev/null
docker wait nginx-spa-test >/dev/null
docker rm nginx-spa-test >/dev/null
containers=$(printf '%s' "$containers" | sed 's/nginx-spa-test//')

echo 'NGINX integration checks passed'
