ARG NGINX_CORE_IMAGE=ghcr.io/gecut/nginx/core:2.0.0
# hadolint ignore=DL3006
FROM ${NGINX_CORE_IMAGE}

COPY etc/nginx/ /etc/nginx/
# COPY default-data/ /default-data/
# RUN ls -RlahF /etc/nginx /default-data /data

# Default environment for nginx template
ENV NGINX_CLIENT_MAX_BODY_SIZE=1k \
    NGINX_SENDFILE=on \
    NGINX_TCP_NOPUSH=on \
    NGINX_TCP_NODELAY=on \
    NGINX_OPEN_FILE_CACHE="max=1000 inactive=30m" \
    NGINX_OPEN_FILE_CACHE_VALID=30s \
    NGINX_OPEN_FILE_CACHE_MIN_USES=2 \
    NGINX_EXPIRES_DYNAMIC=off \
    NGINX_EXPIRES_STATIC=off \
    NGINX_EXPIRES_DEFAULT=off \
    NGINX_LIMIT_REQ_RATE=200 \
    NGINX_LIMIT_REQ_BURST=1000 \
    NGINX_GZIP=on \
    NGINX_GZIP_VARY=off \
    NGINX_GZIP_STATIC=on \
    NGINX_GZIP_COMP_LEVEL=5 \
    NGINX_GZIP_MIN_LENGTH=256 \
    NGINX_DISABLE_SYMLINKS=off \
    NGINX_CDN_S_MAXAGE=31536000 \
    NGINX_CDN_HTML_S_MAXAGE=0 \
    NGINX_CDN_CACHE_HASHED="public, max-age=31536000, immutable" \
    NGINX_CDN_CACHE_UNVERSIONED_STATIC="public, max-age=3600, stale-while-revalidate=30" \
    NGINX_CDN_CACHE_HTML="public, max-age=0, must-revalidate" \
    NGINX_CDN_CACHE_JSON="public, max-age=60, stale-while-revalidate=30" \
    NGINX_CDN_CACHE_SERVICE_WORKER="no-cache" \
    NGINX_CDN_CACHE_ERROR="no-store"

ARG BUILD_VERSION=2.0.0
ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nginx/cdn" \
      org.opencontainers.image.description="A CDN-optimized NGINX image for efficient static content delivery, packaged by Gecut." \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nginx/cdn" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nginx/cdn" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nginx/cdn" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"
