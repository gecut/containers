#!/bin/sh
# Script 20: Run Payload migrations with pnpm

set -e

# Check if migration should be skipped
if [ "$SKIPING_MIGRATE" = "true" ] || [ "$SKIPING_MIGRATE" = "1" ]; then
    echo "[script-20] NO_MIGRATE is set, skipping migration."
    exit 0
fi

# Check prerequisites
if [ ! -f "/app/package.json" ]; then
    echo "[script-20] Error: package.json not found"
    exit 1
fi

if [ ! -f "/app/tsconfig.json" ]; then
    echo "[script-20] Error: tsconfig.json not found"
    exit 1
fi

if [ ! -d "/app/node_modules" ]; then
    echo "[script-20] Error: node_modules not found. Run 'pnpm install' first"
    exit 1
fi

if [ ! -f "/app/src/payload.config.ts" ] && [ ! -f "/app/src/payload.config.js" ]; then
    echo "[script-20] Error: Payload config file not found"
    exit 1
fi

# Check database connection environment
if [ -z "$DATABASE_URL" ] && [ -z "$DATABASE_URI" ]; then
    echo "[script-20] Warning: No DATABASE_URL or DATABASE_URI found. Migration may fail."
fi

echo "[script-20] Running Payload migrations..."
if su-exec nextjs ./node_modules/.bin/payload migrate; then
    echo "[script-20] Payload migrations completed successfully"
else
    echo "[script-20] First migration command failed, trying alternative method..."
    if su-exec nextjs node ./node_modules/payload/dist/bin/migrate.js; then
        echo "[script-20] Payload migrations completed successfully with alternative method"
    else
        echo "[script-20] Error: Both migration methods failed"
        exit 1
    fi
fi
