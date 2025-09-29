#!/usr/bin/env bash
set -e

# Source environment variables
ENV_FILE=${1:-.env}
[ ! -f "$ENV_FILE" ] && echo "Error: Environment file not found: $ENV_FILE" && exit 1 
set -a; source "$ENV_FILE"; set +a

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
  docker compose --env-file "$ENV_FILE" -f "$SERVICES_DIR/$yml_file" -p "$project_name" down --remove-orphans || true
done

echo "All enabled services stopped."

