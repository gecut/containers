#!/bin/sh
# Script 30: Trigger Next.js revalidation.
# This script runs as ROOT but launches the task in the background as the 'nextjs' user.

set -e

# This function contains the actual revalidation logic.
# It will be executed by a sub-shell as the 'nextjs' user.
run_revalidation_task() {
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
}

# Export the function so the sub-shell (sh -c) can see it.
export -f run_revalidation_task

echo "[script-30] Launching revalidation task in the background..."

# Use su-exec to run a new shell as 'nextjs'.
# The 'sh -c "run_revalidation_task"' executes our function.
# The '&' at the end sends the entire command to the background.
su-exec nextjs sh -c "run_revalidation_task" &
