#!/usr/bin/env bash
set -e

read -p "WARNING: This will permanently remove all Docker volumes. Proceed? (confirm YES): " confirm_vol
if [[ "$confirm_vol" != "YES" ]]; then
    echo "Aborting volume removal."
    exit 0
fi

echo "Stopping stacks for cleanup..."
bash "$HOME/homelab/scripts/stop-services.sh"

echo "Removing all containers..."
docker ps -a -q | xargs -r docker rm
echo "All Docker containers have been removed."

echo "Removing all Docker volumes..."
docker volume ls -q | xargs -r docker volume rm
echo "All Docker volumes have been removed."

