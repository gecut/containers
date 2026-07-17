#!/bin/sh
set -eu

test "${NGINX_CORS_ENABLE:-off}" = on && exit 0

ME=$(basename "$0")
echo "$ME: Remove CORS config"
rm -f /etc/nginx/conf.d/location.d/root.d/10-cors.conf

exit 0
