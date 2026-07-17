#!/bin/sh
set -eu

ME=$(basename "$0")

test ! -d "/default-data" && exit 0

echo "$ME: Copy default data from /default-data to $NGINX_DOCUMENT_ROOT without overwriting existing files"
mkdir -p "$NGINX_DOCUMENT_ROOT"
[ -w "$NGINX_DOCUMENT_ROOT" ] || { echo "$ME: Document root is read-only; skip bundled defaults"; exit 0; }
cp -an /default-data/. "$NGINX_DOCUMENT_ROOT/"

exit 0
