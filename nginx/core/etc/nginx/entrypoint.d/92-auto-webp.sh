#!/bin/sh
set -eu

test "${NGINX_AUTO_WEBP:-off}" = on && exit 0

ME=$(basename "$0")
echo "$ME: Remove auto webp config"
rm -f /etc/nginx/conf.d/http.d/42-map-webp.conf
rm -f /etc/nginx/conf.d/location.d/50-webp.conf

exit 0
