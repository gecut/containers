#!/bin/sh
set -eu

ME=$(basename "$0")
template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"
filter="${NGINX_ENVSUBST_FILTER:-^NGINX_}"

[ -d "$template_dir" ] || exit 0
[ -d "$output_dir" ] || mkdir -p "$output_dir"
[ -w "$output_dir" ] || { echo >&2 "$ME: ERROR: $output_dir is not writable"; exit 1; }

defined_envs=$(env | cut -d= -f1 | grep -E "$filter" | sed 's/^/${/; s/$/}/' | tr '\n' ' ' || true)
[ -n "$defined_envs" ] || { echo >&2 "$ME: ERROR: no environment variables match $filter"; exit 1; }

find "$template_dir" -follow -type f -name "*$suffix" -print | sort | while IFS= read -r template; do
  relative_path="${template#"$template_dir"/}"
  output_path="$output_dir/${relative_path%"$suffix"}"
  subdir=$(dirname "$output_path")
  mkdir -p "$subdir"
  temporary=$(mktemp "$subdir/.nginx-template.XXXXXX")
  trap 'rm -f "$temporary"' EXIT HUP INT TERM
  envsubst "$defined_envs" < "$template" > "$temporary"
  chmod 0644 "$temporary"
  mv -f "$temporary" "$output_path"
  trap - EXIT HUP INT TERM
  echo "$ME: rendered $relative_path"
done
