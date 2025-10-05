#!/usr/bin/env bash
# Starts all enabled services in the registry file
set -e

# Source environment variables
source "$(dirname "${BASH_SOURCE[0]}")/doppler-get.sh"

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set in $ENV_FILE" && exit 1

# Other variables
SERVICES_DIR="$BASE_DIR/services"

# Start services enabled in registry file
echo "Starting all enabled services..."
for yml_file in $(jq -r '.services[] | select(.enabled==true) | .path' "$BASE_DIR/$REGISTRY_FILE"); do
  project_name=$(basename "$yml_file" .yml)
  echo "Starting stack: $yml_file (project: $project_name)"
  docker compose -f "$SERVICES_DIR/$yml_file" -p "$project_name" up -d || true
done

echo "All enabled services started."

