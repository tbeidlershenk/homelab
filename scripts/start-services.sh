#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
REGISTRY_FILE="$BASE_DIR/config/registry.json"
ENV_FILE="${1:-$BASE_DIR/.env}"

# Check that .env and registry exist
[ -f "$ENV_FILE" ] || { echo "ERROR: .env file not found at $ENV_FILE"; exit 1; }
[ -f "$REGISTRY_FILE" ] || { echo "ERROR: registry file not found at $REGISTRY_FILE"; exit 1; }

echo "Starting all enabled services..."

# Loop through enabled services using jq
for yml_file in $(jq -r '.services[] | select(.enabled==true) | .path' "$REGISTRY_FILE"); do
  project_name=$(basename "$yml_file" .yml)
  echo "Starting stack: $yml_file (project: $project_name)"
  docker compose --env-file "$ENV_FILE" -f "$yml_file" -p "$project_name" up -d || true
done

echo "All enabled services started."

