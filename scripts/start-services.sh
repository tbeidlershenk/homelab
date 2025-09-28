#!/usr/bin/env bash
set -e

# Source environment variables
ENV_FILE=${1:-.env}
[ ! -f "$ENV_FILE" ] && echo "Error: Environment file not found: $ENV_FILE" && exit 1 
set -a; source "$ENV_FILE"; set +a

# Verify required environment variables are set
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set in $ENV_FILE" && exit 1

# Start services enabled in registry file
echo "Starting all enabled services..."
for yml_file in $(jq -r '.services[] | select(.enabled==true) | .path' "$REGISTRY_FILE"); do
  project_name=$(basename "$yml_file" .yml)
  echo "Starting stack: $yml_file (project: $project_name)"
  docker compose --env-file "$ENV_FILE" -f "$yml_file" -p "$project_name" up -d || true
done

echo "All enabled services started."

