#!/bin/sh
# Script 30: Trigger Next.js revalidation.

set -e

echo "[script-30] Launching revalidation task in the background..."

# The logic is now placed directly inside the 'sh -c' command.
# The single quotes '...' ensure the entire block is treated as one command string.
su-exec nextjs sh -c '
  # Check if the REVALIDATE_SECRET environment variable is set.
  if [ -z "$REVALIDATE_SECRET" ]; then
    echo "[revalidate] REVALIDATE_SECRET not set. Skipping."
    exit 0
  fi

  # Wait for a few seconds to give the Next.js server time to start up.
  echo "[revalidate] Waiting 5 seconds before triggering..."
  sleep 5

  # Define the target origin. Default to localhost inside the container.
  TARGET_ORIGIN=${ORIGIN:-"http://localhost:${PORT:-3000}"}
  REVALIDATE_URL="$TARGET_ORIGIN/api/revalidate?secret=$REVALIDATE_SECRET"

  echo "[revalidate] Sending GET request to: $TARGET_ORIGIN/api/revalidate"

  # Use curl to send the request.
  if curl -sSf --max-time 10 "$REVALIDATE_URL"; then
    echo "[revalidate] Request sent successfully."
  else
    echo "[revalidate] WARNING: Request failed. The server might not be ready or the endpoint is incorrect."
  fi
' &