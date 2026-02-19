#!/bin/sh
set -eu

test "${NGINX_ENABLE_GLOBAL_LIMIT_REQ:-off}" = "on" && exit 0

ME=$(basename "$0")
echo "$ME: Remove global request-limit config (set NGINX_ENABLE_GLOBAL_LIMIT_REQ=on to enable)"
rm -fv /etc/nginx/conf.d/http.d/70-request-limit.conf

exit 0
