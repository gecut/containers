#!/bin/sh
# Script 11: Copy /app/public to PUBLIC_CDN_PATH if valid.
# This script runs as ROOT.

set -e

echo "[script-11] Checking for public CDN sync..."

if [ -d "/app/public" ]; then
    if [ -n "$PUBLIC_CDN_PATH" ] && [ -d "$PUBLIC_CDN_PATH" ]; then
        echo "[script-11] Copying /app/public to $PUBLIC_CDN_PATH ..."
        cp -r /app/public/* "$PUBLIC_CDN_PATH/"
        echo "[script-11] Public files copied successfully."
    else
        echo "[script-11] WARNING: PUBLIC_CDN_PATH is not set or not a valid directory. Skipping."
    fi
else
    echo "[script-11] INFO: /app/public does not exist. Skipping."
fi
