ARG BUILD_VERSION=0.0.0-dev
FROM ghcr.io/gecut/nextjs/base:${BUILD_VERSION}

# Copy only the scripts specific to this variant
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nextjs/with-payload" \
      org.opencontainers.image.description="A Next.js image with PayloadCMS support, packaged by Gecut." \
      org.opencontainers.image.base.name="ghcr.io/gecut/nextjs/base:${BUILD_VERSION}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nextjs/with-payload" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nextjs/with-payload" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nextjs/with-payload" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"


