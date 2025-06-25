# ==============================================================================
# ARGUMENTS
# ==============================================================================
ARG NODE_VERSION=24.2.0-alpine3.21
ARG PACKAGE_MANAGER=pnpm # Supported values: npm, yarn, pnpm

# ==============================================================================
# STAGE 1: BASE
# ... (No changes here)
# ==============================================================================
FROM node:${NODE_VERSION} AS base
WORKDIR /app
RUN apk add --no-cache libc6-compat curl
ENV NEXT_TELEMETRY_DISABLED=1

# ==============================================================================
# STAGE 2: DEPENDENCIES
# ... (No changes here)
# ==============================================================================
FROM base AS dependencies

# Use a RUN --mount command to selectively copy only the files that exist,
# preventing build failures if optional files like .npmrc are missing.
# This requires the BuildKit engine (default in modern Docker).
RUN --mount=type=bind,source=.,target=/src \
    sh -c " \
      echo 'Copying configuration files...'; \
      cp /src/package.json . ; \
      cp /src/.npmrc . 2>/dev/null || true; \
      cp /src/.yarnrc.yml . 2>/dev/null || true; \
      cp /src/pnpm-lock.yaml . 2>/dev/null || true; \
      cp /src/yarn.lock . 2>/dev/null || true; \
      cp /src/package-lock.json* . 2>/dev/null || true; \
    "

RUN \
  if [ "$PACKAGE_MANAGER" = "npm" ]; then echo "Installing with npm..." && npm ci; \
  elif [ "$PACKAGE_MANAGER" = "yarn" ]; then echo "Installing with yarn..." && yarn install --frozen-lockfile; \
  elif [ "$PACKAGE_MANAGER" = "pnpm" ]; then echo "Installing with pnpm..." && npm install -g pnpm && pnpm install --frozen-lockfile --prod=false; \
  else echo "Unsupported package manager: $PACKAGE_MANAGER" && exit 1; \
  fi

# ==============================================================================
# STAGE 3: BUILDER
# ... (No changes here)
# ==============================================================================
FROM base AS builder
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN \
  if [ -f "prisma/schema.prisma" ]; then \
    echo "Prisma schema found, generating client..."; \
    if [ "$PACKAGE_MANAGER" = "npm" ]; then npx prisma generate; \
    elif [ "$PACKAGE_MANAGER" = "yarn" ]; then yarn prisma generate; \
    elif [ "$PACKAGE_MANAGER" = "pnpm" ]; then pnpm prisma generate; \
    fi; \
  fi
RUN \
  echo "Building with $PACKAGE_MANAGER..." && \
  if [ "$PACKAGE_MANAGER" = "npm" ]; then npm run build; \
  elif [ "$PACKAGE_MANAGER" = "yarn" ]; then yarn build; \
  elif [ "$PACKAGE_MANAGER" = "pnpm" ]; then pnpm build; \
  fi

# ==============================================================================
# STAGE 4: RUNNER
# ==============================================================================
FROM node:${NODE_VERSION} AS runner
WORKDIR /app

RUN apk add --no-cache curl su-exec

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
ENV REVALIDATE_SECRET=a-very-secret-token-that-you-should-change

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma

COPY setup.sh /setup.sh
COPY scripts/ /scripts/
RUN chmod +x /setup.sh /scripts/*.sh

EXPOSE ${PORT}

HEALTHCHECK --interval=60s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://${HOSTNAME}:${PORT}/api/health || exit 1

# The container will start by running setup.sh as root.
ENTRYPOINT ["/setup.sh"]

# The default command is passed as arguments ("$@") to the entrypoint script.
CMD ["node", "server.js"]
