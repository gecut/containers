#!/bin/sh
# Script 99: Final entrypoint with graceful shutdown.
# This script takes over the process and starts the main application.

set -e

echo "[script-99] Starting application with graceful shutdown support..."

# Graceful shutdown handler
shutdown_handler() {
    echo "[script-99] Received shutdown signal. Gracefully stopping..."
    if [ -n "$APP_PID" ]; then
        kill -TERM "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
    fi
    echo "[script-99] Application stopped gracefully"
    exit 0
}

# Trap shutdown signals
trap shutdown_handler SIGTERM SIGINT SIGQUIT

echo "[script-99] Handing over to the main application as user 'nextjs'..."
echo "------------------------------------------------"

# Start application in background and capture PID
su-exec nextjs "$@" &
APP_PID=$!

# Wait for the application to finish
wait "$APP_PID"
