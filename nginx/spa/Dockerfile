ARG NGINX_CDN_IMAGE=ghcr.io/gecut/nginx/cdn:2.0.0
# hadolint ignore=DL3006
FROM ${NGINX_CDN_IMAGE}

RUN rm -f /default-data/index.html

COPY etc/nginx/templates/ /etc/nginx/templates/
COPY etc/nginx/entrypoint.d/ /docker-entrypoint.d/
RUN chmod a+rx /docker-entrypoint.d/*.sh

ENV NGINX_SPA_INDEX_URI=/index.html

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD host="${NGINX_FORCE_DOMAIN:-127.0.0.1}"; wget -q --header "Host: $host" -O /dev/null http://127.0.0.1/server-info && wget -q --header "Host: $host" -O /dev/null "http://127.0.0.1${NGINX_SPA_INDEX_URI}" || exit 1

ARG BUILD_VERSION=1.0.0
ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nginx/spa" \
      org.opencontainers.image.description="Production NGINX image for static single-page applications, packaged by Gecut." \
      org.opencontainers.image.base.name="ghcr.io/gecut/nginx/cdn:2.0.0" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nginx/spa" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nginx/spa" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nginx/spa" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"
