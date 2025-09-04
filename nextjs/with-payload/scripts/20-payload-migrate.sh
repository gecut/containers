#!/bin/sh
# Script 20: Run Payload migrations with pnpm

set -e

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

if [ ! -f "/app/payload.config.ts" ] && [ ! -f "/app/payload.config.js" ]; then
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
    echo "[script-20] Error: Payload migration failed"
    exit 1
fi
