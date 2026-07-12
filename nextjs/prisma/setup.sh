#!/bin/sh
# This script runs as ROOT and acts as an orchestrator.
# It executes all executable shell scripts inside the /scripts/ directory in alphabetical order.

set -e

echo "[setup] Starting container setup by running scripts in /scripts/..."

# Loop through all executable files in the /scripts/ directory.
# The 'for' loop naturally processes them in alphabetical/numerical order.
for script in /scripts/*.sh; do
  if [ -x "$script" ]; then
    echo "------------------------------------------------"
    echo "[setup] Executing script: $script"
    
    # Execute the script.
    # The last script (99-entrypoint.sh) will use 'exec' to take over the process.
    "$script" "$@"
  fi
done

echo "------------------------------------------------"
echo "[setup] WARNING: No entrypoint script found to take over. The container will exit."
# This message will only be shown if a script like '99-entrypoint.sh' with 'exec' is missing.
