#!/bin/sh
# Script 10: Fix storage permissions.
# This script runs as ROOT.

set -e
echo "[script-10] Searching for storage paths to fix permissions..."

# Dynamically find and fix permissions for storage paths.
env | grep '_STORAGE_PATH=' | cut -d'=' -f2- | while read -r path; do
    if [ -n "$path" ] && [ -d "$path" ]; then
        echo "[script-10] Fixing permissions for '$path'..."
        chown -R nextjs:nodejs "$path"
    else
        echo "[script-10] WARNING: Path '$path' is not a directory or does not exist. Skipping."
    fi
done || true
