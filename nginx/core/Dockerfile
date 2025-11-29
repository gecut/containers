FROM ghcr.io/gecut/nginx/base:latest

RUN apk add --no-cache curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --start-interval=1s --retries=3 CMD curl -fso /dev/null http://localhost/server-info || exit 1

WORKDIR /data

COPY etc/nginx/ /etc/nginx/
COPY default-data/ /default-data/
# RUN ls -RlahF /etc/nginx /default-data /data

# Default environment for nginx template
ENV NGINX_ACCESS_LOG="/var/log/nginx/access.log json" \
    NGINX_ERROR_LOG_LEVEL=notice \
    NGINX_WORKER_CONNECTIONS=2048 \
    NGINX_LIMIT_REQ_ERROR=503 \
    NGINX_LIMIT_REQ_LOG=notice \
    NGINX_AUTOINDEX=off \
    NGINX_DOCUMENT_ROOT=/data \
    NGINX_FORCE_DOMAIN="" \
    NGINX_FORCE_DOMAIN_STATUS=307 \
    NGINX_FORCE_REDIRECT_STATUS=307 \
    NGINX_AUTO_WEBP="" \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENTRYPOINT_QUIET_LOGS="" \
    NGINX_CORS_ENABLE="" \
    NGINX_CORS_ORIGIN="*" \
    NGINX_CORS_METHODS="GET, OPTIONS" \
    NGINX_CORS_HEADERS="*" \
    NGINX_CORS_MAXAGE=86400 \
    NGINX_RESOLVERS="127.0.0.11" \
    NGINX_RESOLVER_VALID=10s

ENV NGINX_CLIENT_MAX_BODY_SIZE=10m \
    NGINX_SENDFILE=on \
    NGINX_SENDFILE_MAX_CHUNK=2m \
    NGINX_TCP_NOPUSH=on \
    NGINX_TCP_NODELAY=on \
    NGINX_OPEN_FILE_CACHE="max=1000 inactive=30m" \
    NGINX_OPEN_FILE_CACHE_VALID=1s \
    NGINX_OPEN_FILE_CACHE_MIN_USES=2 \
    NGINX_OUTPUT_BUFFERS="8 16k" \
    NGINX_EXPIRES_DYNAMIC=epoch \
    NGINX_EXPIRES_STATIC=epoch \
    NGINX_EXPIRES_DEFAULT=epoch \
    NGINX_LIMIT_REQ_RATE=200 \
    NGINX_LIMIT_REQ_BURST=1000 \
    NGINX_GZIP=on \
    NGINX_GZIP_VARY=on \
    NGINX_GZIP_COMP_LEVEL=5 \
    NGINX_GZIP_MIN_LENGTH=256 \
    NGINX_DISABLE_SYMLINKS=if_not_owner

ARG BUILD_VERSION=0.0.0-core
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

