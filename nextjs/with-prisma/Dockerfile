ARG NODE_VERSION=24.2.0-alpine3.21

# This is the one and only stage for the base image
FROM node:${NODE_VERSION}

WORKDIR /app

# Install runtime dependencies needed for the scripts
RUN apk add --no-cache curl su-exec

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
ENTRYPOINT ["/setup.sh"]

ARG BUILD_VERSION=0.0.0-dev
ARG BUILD_REV
ARG BUILD_DATE
LABEL org.opencontainers.image.title="gecut/nextjs/with-prisma" \
      org.opencontainers.image.description="A Next.js image with Prisma support for database migrations, packaged by Gecut." \
      org.opencontainers.image.base.name="docker.io/library/node:24.2.0-alpine3.21" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="Gecut" \
      org.opencontainers.image.source="https://github.com/gecut/containers/tree/main/nextjs/with-prisma" \
      org.opencontainers.image.url="https://github.com/gecut/containers/tree/main/nextjs/with-prisma" \
      org.opencontainers.image.documentation="https://github.com/gecut/containers/tree/main/nextjs/with-prisma" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://mm25zamanian.ir)"


