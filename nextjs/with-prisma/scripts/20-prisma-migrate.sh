#!/bin/sh
# Script 20: Run Prisma migrations.
# This script runs as ROOT but executes the command as the 'nextjs' user.

set -e

if [ "$SKIP_DB_PUSH" = "true" ] || [ "$SKIP_DB_PUSH" = "1" ]; then
    echo "[script-20] 'SKIP_DB_PUSH' is set, skipping migration."
    exit 0
fi

if [ -f "/app/prisma/schema.prisma" ]; then
    echo "[script-20] Prisma schema found. Running migrations as 'nextjs' user..."
    su-exec nextjs npx prisma@6.16 db push --skip-generate
else
    echo "[script-20] No Prisma schema found. Skipping db pushing."
fi
