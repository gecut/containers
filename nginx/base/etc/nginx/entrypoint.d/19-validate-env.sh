#!/bin/sh
set -eu

fail() {
  echo >&2 "19-validate-env.sh: ERROR: $1"
  exit 1
}

validate_enum() {
  name=$1
  allowed=$2
  value=$(printenv "$name" 2>/dev/null || true)
  [ -z "$value" ] && return 0
  case " $allowed " in *" $value "*) ;; *) fail "$name must be one of: $allowed" ;; esac
}

validate_uint() {
  name=$1
  value=$(printenv "$name" 2>/dev/null || true)
  [ -z "$value" ] && return 0
  case "$value" in *[!0-9]*|'') fail "$name must be an unsigned integer" ;; esac
}

validate_safe_text() {
  name=$1
  value=$(printenv "$name" 2>/dev/null || true)
  [ -z "$value" ] && return 0
  printf '%s' "$value" | grep -q "[[:cntrl:]'\"\\]" && fail "$name contains unsafe characters"
  return 0
}

validate_pattern() {
  name=$1
  pattern=$2
  description=$3
  value=$(printenv "$name" 2>/dev/null || true)
  [ -z "$value" ] && return 0
  printf '%s' "$value" | grep -Eq "$pattern" || fail "$name must be $description"
}

for name in NGINX_MULTI_ACCEPT NGINX_AUTOINDEX NGINX_CORS_ENABLE NGINX_AUTO_WEBP \
  NGINX_ENABLE_GLOBAL_LIMIT_REQ NGINX_DISALLOW_ROBOTS NGINX_GZIP NGINX_GZIP_VARY \
  NGINX_GZIP_STATIC NGINX_SENDFILE NGINX_TCP_NOPUSH NGINX_TCP_NODELAY; do
  validate_enum "$name" "on off"
done

validate_enum NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE "1"
validate_enum NGINX_ERROR_LOG_LEVEL "debug info notice warn error crit alert emerg"
validate_enum NGINX_LIMIT_REQ_LOG "info notice warn error"
validate_enum NGINX_CANONICAL_SCHEME "http https"
validate_enum NGINX_LIMIT_REQ_ERROR "429"
validate_enum NGINX_FORCE_DOMAIN_STATUS "301 302 307 308"
validate_enum NGINX_FORCE_REDIRECT_STATUS "301 302 307 308"
validate_enum NGINX_DISABLE_SYMLINKS "off on if_not_owner"

for name in NGINX_WORKER_CONNECTIONS NGINX_WORKER_RLIMIT_NOFILE NGINX_KEEPALIVE_REQUESTS \
  NGINX_OPEN_FILE_CACHE_MIN_USES NGINX_LIMIT_REQ_RATE NGINX_LIMIT_REQ_BURST \
  NGINX_GZIP_COMP_LEVEL NGINX_GZIP_MIN_LENGTH NGINX_CDN_S_MAXAGE NGINX_CDN_HTML_S_MAXAGE; do
  validate_uint "$name"
done
validate_uint NGINX_CORS_MAXAGE

validate_pattern NGINX_CLIENT_MAX_BODY_SIZE '^[0-9]+[kKmMgG]?$' 'a non-negative NGINX size'
validate_pattern NGINX_OPEN_FILE_CACHE_VALID '^[0-9]+(ms|s|m|h|d)?$' 'a valid time value'
validate_pattern NGINX_RESOLVER_VALID '^[0-9]+(ms|s|m|h|d)?$' 'a valid time value'
validate_pattern NGINX_KEEPALIVE_TIMEOUT '^[0-9]+(ms|s|m|h|d)?$' 'a valid time value'
validate_pattern NGINX_REAL_IP_HEADER '^[A-Za-z0-9-]+$' 'a valid HTTP header name'
validate_pattern NGINX_ACCESS_LOG '^(/[^ ;]+|off)( [A-Za-z0-9_-]+)?$' 'an absolute log path with an optional format, or off'

if [ -n "${NGINX_OPEN_FILE_CACHE:-}" ]; then
  case "$NGINX_OPEN_FILE_CACHE" in *';'*|*'{'*|*'}'*) fail "NGINX_OPEN_FILE_CACHE contains unsafe directive characters" ;; esac
fi

case "${NGINX_GZIP_COMP_LEVEL:-5}" in [1-9]) ;; *) fail "NGINX_GZIP_COMP_LEVEL must be between 1 and 9" ;; esac

for name in NGINX_EXPIRES_DYNAMIC NGINX_EXPIRES_STATIC NGINX_EXPIRES_DEFAULT; do
  validate_pattern "$name" '^(epoch|max|off|[+-]?[0-9]+[smhdwMy]?)$' 'a safe NGINX expires value'
done

if [ -n "${NGINX_DOCUMENT_ROOT:-}" ]; then
  case "$NGINX_DOCUMENT_ROOT" in /*) ;; *) fail "NGINX_DOCUMENT_ROOT must be an absolute path" ;; esac
  case "$NGINX_DOCUMENT_ROOT" in *..*|*[[:space:]]*) fail "NGINX_DOCUMENT_ROOT contains unsafe path segments" ;; esac
fi

if [ -n "${NGINX_FORCE_DOMAIN:-}" ]; then
  case "$NGINX_FORCE_DOMAIN" in *[!A-Za-z0-9.-]*|.*|*.) fail "NGINX_FORCE_DOMAIN must be a hostname" ;; esac
fi

if [ -n "${NGINX_RESOLVERS:-}" ] && [ "$NGINX_RESOLVERS" != local ]; then
  case "$NGINX_RESOLVERS" in *[!0-9A-Fa-f:.\[\]\ ]*) fail "NGINX_RESOLVERS must contain IP literals or 'local'" ;; esac
fi

if [ -n "${NGINX_TRUSTED_PROXY_CIDRS:-}" ]; then
  case "$NGINX_TRUSTED_PROXY_CIDRS" in *[!0-9A-Fa-f:.,/\;\ ]*) fail "NGINX_TRUSTED_PROXY_CIDRS contains unsafe characters" ;; esac
fi

if [ -n "${NGINX_SPA_INDEX_URI:-}" ]; then
  printf '%s' "$NGINX_SPA_INDEX_URI" | grep -q '[[:cntrl:]]' && fail "NGINX_SPA_INDEX_URI contains control characters"
  case "$NGINX_SPA_INDEX_URI" in /*) ;; *) fail "NGINX_SPA_INDEX_URI must be an absolute local URI" ;; esac
  case "$NGINX_SPA_INDEX_URI" in *..*|*\?*|*\#*|*[[:space:]]*) fail "NGINX_SPA_INDEX_URI contains unsafe characters" ;; esac
fi

for name in NGINX_OPEN_FILE_CACHE NGINX_CORS_ORIGIN NGINX_CORS_METHODS NGINX_CORS_HEADERS \
  NGINX_CDN_CACHE_HASHED NGINX_CDN_CACHE_UNVERSIONED_STATIC NGINX_CDN_CACHE_HTML \
  NGINX_CDN_CACHE_JSON NGINX_CDN_CACHE_SERVICE_WORKER NGINX_CDN_CACHE_ERROR; do
  validate_safe_text "$name"
done
