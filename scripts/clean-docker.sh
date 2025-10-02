#!/usr/bin/env bash
# This script cleans up Docker resources, optionally purging volumes
set -e

# Source environment variables
source "$(dirname "${BASH_SOURCE[0]}")/doppler-get.sh"

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not configured." && exit 1

read -p "WARNING: This will permanently remove all Docker volumes. Proceed? (confirm YES): " confirm_vol
if [[ "$confirm_vol" != "YES" ]]; then
    echo "Aborting volume removal." && exit 0
fi

echo "Stopping stacks for cleanup..."
bash "$BASE_DIR/scripts/stop-services.sh"

echo "Removing all containers..."
docker ps -a -q | xargs -r docker rm
echo "All Docker containers have been removed."

echo "Removing all Docker volumes..."
sudo rm -rf $BASE_DIR/volumes
echo "All Docker volumes have been removed."

