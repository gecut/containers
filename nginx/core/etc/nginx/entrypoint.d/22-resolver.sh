#!/bin/sh
set -eu

ME=$(basename "$0")
OUT_FILE=/etc/nginx/conf.d/http.d/05-resolver.conf
RESOLVERS="${NGINX_RESOLVERS:-}"

if [ -z "$RESOLVERS" ]; then
  rm -f "$OUT_FILE"
  exit 0
fi

if [ "$RESOLVERS" = local ]; then
  RESOLVERS="${NGINX_LOCAL_RESOLVERS:-}"
fi

[ -n "$RESOLVERS" ] || { echo >&2 "$ME: ERROR: no local resolver was detected"; exit 1; }
TEMP_FILE=$(mktemp /etc/nginx/conf.d/http.d/.resolver.XXXXXX)
trap 'rm -f "$TEMP_FILE"' EXIT HUP INT TERM
printf 'resolver %s valid=%s;\nresolver_timeout 5s;\n' "$RESOLVERS" "$NGINX_RESOLVER_VALID" > "$TEMP_FILE"
mv -f "$TEMP_FILE" "$OUT_FILE"
trap - EXIT HUP INT TERM
