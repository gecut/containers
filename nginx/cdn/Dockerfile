FROM ghcr.io/gecut/nginx/core:latest

# COPY etc/nginx/ /etc/nginx/
# COPY default-data/ /default-data/
# RUN ls -RlahF /etc/nginx /default-data /data

# Default environment for nginx template
ENV NGINX_CLIENT_MAX_BODY_SIZE=1k \
    NGINX_SENDFILE=on \
    NGINX_SENDFILE_MAX_CHUNK=2m \
    NGINX_TCP_NOPUSH=on \
    NGINX_TCP_NODELAY=on \
    NGINX_OPEN_FILE_CACHE="max=1000 inactive=30m" \
    NGINX_OPEN_FILE_CACHE_VALID=1M \
    NGINX_OPEN_FILE_CACHE_MIN_USES=2 \
    NGINX_OUTPUT_BUFFERS="8 16k" \
    NGINX_EXPIRES_DYNAMIC=max \
    NGINX_EXPIRES_STATIC=max \
    NGINX_EXPIRES_DEFAULT=max \
    NGINX_LIMIT_REQ_RATE=200 \
    NGINX_LIMIT_REQ_BURST=1000 \
    NGINX_GZIP=on \
    NGINX_GZIP_VARY=on \
    NGINX_GZIP_COMP_LEVEL=5 \
    NGINX_GZIP_MIN_LENGTH=256 \
    NGINX_DISABLE_SYMLINKS=if_not_owner

ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nginx-cdn" \
      org.opencontainers.image.description="This is a high-performance version of NGINX, which has been enhanced by Gecut Web for the purpose of serving static content efficiently." \
      org.opencontainers.image.base.name="ghcr.io/gecut/nginx-core:3.5.0" \
      org.opencontainers.image.version="3.5.0" \
      org.opencontainers.image.ref.name="3.5.0-nginx1.27.4-alpine-slim" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut Web" \
      org.opencontainers.image.source="https://github.com/gecut/containers" \
      org.opencontainers.image.url="https://github.com/gecut/containers" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"
