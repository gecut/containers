#!/bin/sh
set -eu

ME=$(basename "$0")
OUT_FILE=/etc/nginx/conf.d/http.d/10-real-ip.conf

TRUSTED_CIDRS="${NGINX_TRUSTED_PROXY_CIDRS:-}"
if [ -z "$TRUSTED_CIDRS" ]; then
  echo "$ME: Real IP rewriting is disabled"
  rm -f "$OUT_FILE"
  exit 0
fi

echo "$ME: Render trusted real-ip CIDRs into $OUT_FILE"
TEMP_FILE=$(mktemp /etc/nginx/conf.d/http.d/.real-ip.XXXXXX)
trap 'rm -f "$TEMP_FILE"' EXIT HUP INT TERM
printf 'real_ip_header %s;\nreal_ip_recursive on;\n' "$NGINX_REAL_IP_HEADER" > "$TEMP_FILE"

count=0
for cidr in $(printf '%s' "$TRUSTED_CIDRS" | tr ',;' '  '); do
  [ -z "$cidr" ] && continue
  case "$cidr" in */*) ;; *) echo >&2 "$ME: ERROR: trusted proxy must be an explicit CIDR: $cidr"; exit 1 ;; esac
  printf 'set_real_ip_from %s;\n' "$cidr" >> "$TEMP_FILE"
  count=$((count + 1))
done

[ "$count" -gt 0 ] || { echo >&2 "$ME: ERROR: no trusted proxy CIDR was provided"; exit 1; }

mv -f "$TEMP_FILE" "$OUT_FILE"
trap - EXIT HUP INT TERM

exit 0
