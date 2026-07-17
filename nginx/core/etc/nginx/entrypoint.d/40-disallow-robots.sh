#!/bin/sh

set -eu

ME=$(basename "$0")

test "${NGINX_DISALLOW_ROBOTS:-off}" = on || exit 0

if cmp -s "$NGINX_DOCUMENT_ROOT/robots.txt" /default-data/robots.txt; then
  echo "$ME: Replace default robots.txt to disallow all robots"
  [ -w "$NGINX_DOCUMENT_ROOT" ] || { echo >&2 "$ME: ERROR: document root is read-only"; exit 1; }
  cp -f /etc/nginx/robots-disallow.txt "$NGINX_DOCUMENT_ROOT/robots.txt"
else
  echo "$ME: Preserve consumer-provided robots.txt"
fi

exit 0
