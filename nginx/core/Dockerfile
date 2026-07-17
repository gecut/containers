ARG NGINX_BASE_IMAGE=ghcr.io/gecut/nginx/base:2.0.0
# hadolint ignore=DL3006
FROM ${NGINX_BASE_IMAGE}

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD host="${NGINX_FORCE_DOMAIN:-127.0.0.1}"; wget -q --header "Host: $host" -O /dev/null http://127.0.0.1/server-info || exit 1

WORKDIR /data

COPY etc/nginx/templates/ /etc/nginx/templates/
COPY etc/nginx/entrypoint.d/ /docker-entrypoint.d/
COPY etc/nginx/robots-disallow.txt /etc/nginx/robots-disallow.txt
COPY default-data/ /default-data/
RUN chmod a+rx /docker-entrypoint.d/*.sh

# Default environment for nginx template
ENV NGINX_ACCESS_LOG="/var/log/nginx/access.log json" \
    NGINX_ERROR_LOG_LEVEL=notice \
    NGINX_WORKER_CONNECTIONS=2048 \
    NGINX_WORKER_RLIMIT_NOFILE=262144 \
    NGINX_MULTI_ACCEPT=off \
    NGINX_LIMIT_REQ_ERROR=429 \
    NGINX_LIMIT_REQ_LOG=notice \
    NGINX_ENABLE_GLOBAL_LIMIT_REQ=off \
    NGINX_AUTOINDEX=off \
    NGINX_DOCUMENT_ROOT=/data \
    NGINX_FORCE_DOMAIN="" \
    NGINX_FORCE_DOMAIN_STATUS=308 \
    NGINX_CANONICAL_SCHEME=https \
    NGINX_FORCE_REDIRECT_STATUS=307 \
    NGINX_AUTO_WEBP=off \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENTRYPOINT_QUIET_LOGS="" \
    NGINX_CORS_ENABLE=off \
    NGINX_CORS_ORIGIN="*" \
    NGINX_CORS_METHODS="GET, OPTIONS" \
    NGINX_CORS_HEADERS="*" \
    NGINX_CORS_MAXAGE=86400 \
    NGINX_REAL_IP_HEADER="X-Forwarded-For" \
    NGINX_TRUSTED_PROXY_CIDRS="" \
    NGINX_RESOLVERS="" \
    NGINX_RESOLVER_VALID=10s

ENV NGINX_CLIENT_MAX_BODY_SIZE=10m \
    NGINX_SENDFILE=on \
    NGINX_TCP_NOPUSH=on \
    NGINX_TCP_NODELAY=on \
    NGINX_OPEN_FILE_CACHE="max=1000 inactive=30m" \
    NGINX_OPEN_FILE_CACHE_VALID=30s \
    NGINX_OPEN_FILE_CACHE_MIN_USES=2 \
    NGINX_KEEPALIVE_TIMEOUT=65 \
    NGINX_KEEPALIVE_REQUESTS=1000 \
    NGINX_EXPIRES_DYNAMIC=epoch \
    NGINX_EXPIRES_STATIC=epoch \
    NGINX_EXPIRES_DEFAULT=epoch \
    NGINX_LIMIT_REQ_RATE=200 \
    NGINX_LIMIT_REQ_BURST=100 \
    NGINX_GZIP=on \
    NGINX_GZIP_VARY=on \
    NGINX_GZIP_STATIC=on \
    NGINX_GZIP_COMP_LEVEL=5 \
    NGINX_GZIP_MIN_LENGTH=256 \
    NGINX_DISABLE_SYMLINKS=off \
    NGINX_DISALLOW_ROBOTS=off

ARG BUILD_VERSION=2.0.0
ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nginx/core" \
      org.opencontainers.image.description="A high-performance NGINX image for serving static content, packaged by Gecut." \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nginx/core" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nginx/core" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nginx/core" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"
