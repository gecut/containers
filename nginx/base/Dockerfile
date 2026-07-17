FROM docker.io/library/nginx:1.30.4-alpine-slim@sha256:ddde39c6e51f02fde7410c2e9c234cf2d0a4c7bdbbe176aeb37d8ad7ab4eb58c

RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/nginx.conf /var/www/html /usr/share/nginx/html /data \
    && mkdir -p /data /etc/nginx/conf.d/http.d /etc/nginx/conf.d/server.d
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY etc/nginx/templates/ /etc/nginx/templates/
COPY etc/nginx/entrypoint.d/ /docker-entrypoint.d/
RUN chmod a+rx /docker-entrypoint.d/*.sh

EXPOSE 80
STOPSIGNAL SIGQUIT
WORKDIR /data
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

# Default environment for nginx template
ENV NGINX_ENVSUBST_FILTER="^NGINX_" \
    NGINX_WORKER_CONNECTIONS=2048 \
    NGINX_WORKER_RLIMIT_NOFILE=262144 \
    NGINX_MULTI_ACCEPT=off \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENTRYPOINT_QUIET_LOGS=""

ARG BUILD_VERSION=2.0.0
ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nginx/base" \
      org.opencontainers.image.description="Base NGINX image with a modular entrypoint system, packaged by Gecut." \
      org.opencontainers.image.base.name="docker.io/library/nginx:1.30.4-alpine-slim@sha256:ddde39c6e51f02fde7410c2e9c234cf2d0a4c7bdbbe176aeb37d8ad7ab4eb58c" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nginx/base" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nginx/base" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nginx/base" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"
