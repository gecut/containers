#!/bin/sh
set -eu

echo "99-validate-nginx.sh: validating rendered NGINX configuration"
nginx -t
