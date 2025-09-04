#!/bin/sh
# Script 10: Fix storage permissions.
# This script runs as ROOT.

set -e
echo "[script-10] Searching for storage paths to fix permissions..."

# Check if nextjs user exists
if ! id nextjs >/dev/null 2>&1; then
    echo "[script-10] Error: nextjs user not found"
    exit 1
fi

# Fix permissions for both _STORAGE_PATH and _DIR patterns
env | grep -E '_(STORAGE_PATH|DIR)=' | cut -d'=' -f2- | while read -r path; do
    if [ -n "$path" ]; then
        echo "[script-10] Processing path: '$path'"
        
        # Create directory if it doesn't exist
        mkdir -p "$path"
        
        # Fix permissions
        chown -R nextjs:nodejs "$path"
        echo "[script-10] Permissions fixed for '$path'"
    fi
done || true
