#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
REGISTRY_FILE="$BASE_DIR/services/registry.yml"
ENV_FILE="$BASE_DIR/${1:-.env}"

# Check that .env and registry exist
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

if [ ! -f "$REGISTRY_FILE" ]; then
  echo "ERROR: registry file not found at $REGISTRY_FILE"
  exit 1
fi

echo "Starting all enabled services..."

# Loop through enabled services in the registry
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Starting stack: $yml_file (project: $project_name)"

  # Start the stack
  docker compose --env-file "$ENV_FILE" -f "$yml_file" -p "$project_name" up -d || true
done < <(yq eval '.services[] | select(.enabled == true) | .path' "$REGISTRY_FILE")

echo "All enabled services started."
