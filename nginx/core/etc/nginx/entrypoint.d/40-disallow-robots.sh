#!/bin/sh

set -eu

ME=$(basename "$0")

test "${NGINX_DISALLOW_ROBOTS:-off}" = on || exit 0

robots_path="$NGINX_DOCUMENT_ROOT/robots.txt"

if [ ! -e "$robots_path" ] || cmp -s "$robots_path" /default-data/robots.txt; then
  echo "$ME: Install bundled robots.txt that disallows all robots"
  [ -w "$NGINX_DOCUMENT_ROOT" ] || { echo >&2 "$ME: ERROR: document root is read-only"; exit 1; }
  temporary=$(mktemp "$NGINX_DOCUMENT_ROOT/.robots.XXXXXX")
  trap 'rm -f "$temporary"' EXIT HUP INT TERM
  cp /etc/nginx/robots-disallow.txt "$temporary"
  chmod 0644 "$temporary"
  mv -f "$temporary" "$robots_path"
  trap - EXIT HUP INT TERM
else
  echo "$ME: Preserve consumer-provided robots.txt"
fi

exit 0
