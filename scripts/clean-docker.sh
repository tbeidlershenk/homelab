#!/usr/bin/env bash
set -e

# Source environment variables
ENV_FILE=${1:-.env}
[ ! -f "$ENV_FILE" ] && echo "Error: Environment file not found: $ENV_FILE" && exit 1 
set -a; source "$ENV_FILE"; set +a

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1

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

