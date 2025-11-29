####################
# Build arguments
####################
ARG NODE_VERSION=22.12.0
ARG APP_DIR=/app

# This is the one and only stage for the base image
FROM node:${NODE_VERSION}-alpine

WORKDIR /app

# Install runtime dependencies needed for the scripts
RUN apk add --no-cache libc6-compat vips curl su-exec tini
RUN rm -rf /var/cache/apk/*

# Create a non-root user and set up the environment
ENV NODE_ENV=production
ENV PORT=3000
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the startup scripts that define the platform's behavior
COPY setup.sh /setup.sh
COPY scripts/ /scripts/
RUN chmod +x /setup.sh /scripts/*.sh

# Expose the port and define the entrypoint
EXPOSE ${PORT}
STOPSIGNAL SIGTERM
ENTRYPOINT ["/sbin/tini","-g","--","/setup.sh"]

ARG BUILD_VERSION=0.0.0-dev
ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nextjs/base" \
      org.opencontainers.image.description="Base image for running Next.js applications, packaged by Gecut." \
      org.opencontainers.image.base.name="docker.io/library/node:22.12.0-alpine" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nextjs/base" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nextjs/base" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nextjs/base" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"


