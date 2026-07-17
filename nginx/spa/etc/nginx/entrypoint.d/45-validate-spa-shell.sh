#!/bin/sh
set -eu

document_root=${NGINX_DOCUMENT_ROOT%/}
shell_path="${document_root}${NGINX_SPA_INDEX_URI}"

if [ ! -f "$shell_path" ] || [ ! -r "$shell_path" ]; then
  echo >&2 "45-validate-spa-shell.sh: ERROR: SPA shell is missing or unreadable: $shell_path"
  exit 1
fi

echo "45-validate-spa-shell.sh: SPA shell is ready: $shell_path"
