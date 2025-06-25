#!/bin/sh
# Script 99: Final entrypoint.
# This script takes over the process and starts the main application.
# It MUST be the last script to run.

set -e

echo "[script-99] Handing over to the main application as user 'nextjs'..."
echo "------------------------------------------------"

# Use 'exec' to replace the current shell process with the application process.
# Use 'su-exec' to drop from ROOT to the 'nextjs' user.
# "$@" passes along the CMD from the Dockerfile (e.g., "node", "server.js").
exec su-exec nextjs "$@"
