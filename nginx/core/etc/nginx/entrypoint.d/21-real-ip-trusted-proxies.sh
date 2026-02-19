#!/bin/sh
set -eu

ME=$(basename "$0")
OUT_FILE=/etc/nginx/conf.d/http.d/10-real-ip-trusted.conf

TRUSTED_CIDRS="${NGINX_TRUSTED_PROXY_CIDRS:-}"
if [ -z "$TRUSTED_CIDRS" ]; then
  TRUSTED_CIDRS="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32"
fi

echo "$ME: Render trusted real-ip CIDRs into $OUT_FILE"
: > "$OUT_FILE"

for cidr in $(printf '%s' "$TRUSTED_CIDRS" | tr ',;' '  '); do
  [ -z "$cidr" ] && continue
  printf 'set_real_ip_from  %s;\n' "$cidr" >> "$OUT_FILE"
done

if [ ! -s "$OUT_FILE" ]; then
  echo "$ME: No valid CIDR detected, using loopback fallback"
  printf 'set_real_ip_from  127.0.0.1/32;\n' > "$OUT_FILE"
fi

exit 0
