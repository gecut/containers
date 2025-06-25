#!/bin/sh
# Script 20: Run Prisma migrations.
# This script runs as ROOT but executes the command as the 'nextjs' user.

set -e

if [ -f "/app/prisma/schema.prisma" ]; then
    echo "[script-20] Prisma schema found. Running migrations as 'nextjs' user..."
    su-exec nextjs npx prisma migrate deploy
else
    echo "[script-20] No Prisma schema found. Skipping migrations."
fi
