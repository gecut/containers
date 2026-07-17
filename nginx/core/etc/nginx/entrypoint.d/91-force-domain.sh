#!/bin/sh
set -eu

test -n "${NGINX_FORCE_DOMAIN:-}" && exit 0

ME=$(basename "$0")
echo "$ME: Remove force domain location config"
rm -f /etc/nginx/conf.d/location.d/35-force-domain.conf

exit 0
