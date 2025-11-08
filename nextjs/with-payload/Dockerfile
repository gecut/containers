# This is the one and only stage for the base image
FROM ghcr.io/gecut/nextjs/base:latest

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

