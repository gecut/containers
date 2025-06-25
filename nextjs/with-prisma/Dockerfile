# Dockerfile for: ghcr.io/gecut/nextjs/with-prisma
# This Dockerfile creates the BASE IMAGE. It only contains the runtime environment.

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

# The default command to run the application
CMD ["node", "server.js"]
