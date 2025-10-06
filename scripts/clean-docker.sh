#!/usr/bin/env bash
# This script cleans up Docker resources, optionally purging volumes
set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

read -p "WARNING: This will permanently remove all Docker volumes. Proceed? (confirm YES): " confirm_vol
if [[ "$confirm_vol" != "YES" ]]; then
    echo "Aborting volume removal." && exit 0
fi

echo "Stopping stacks for cleanup..."
source "$script_context/helpers/stop_all.sh"

echo "Removing all containers..."
docker ps -a -q | xargs -r docker rm
echo "All Docker containers have been removed."

echo "Removing all Docker volumes..."
sudo rm -rf $BASE_DIR/volumes
echo "All Docker volumes have been removed."

