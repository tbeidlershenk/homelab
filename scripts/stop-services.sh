#!/usr/bin/env bash
# Stops all enabled services in the registry file
set -e

# Source environment variables
source "$(dirname "${BASH_SOURCE[0]}")/doppler-get.sh"

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set in $ENV_FILE" && exit 1

# Other variables
SERVICES_DIR="$BASE_DIR/services"

# Stop services enabled in registry file
echo "Stopping all enabled services..."
for yml_file in $(jq -r '.services[] | .path' "$REGISTRY_FILE"); do
  project_name=$(basename "$yml_file" .yml)
  echo "Stopping stack: $yml_file (project: $project_name)"
  docker compose -f "$SERVICES_DIR/$yml_file" -p "$project_name" down --remove-orphans || true
done

echo "All enabled services stopped."

