#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
SERVICES_DIR="$BASE_DIR/services"
REGISTRY_FILE="$BASE_DIR/config/registry.json"
ENV_FILE="$BASE_DIR/${1:-.env}"

[ -f "$ENV_FILE" ] || { echo "ERROR: .env file not found at $ENV_FILE"; exit 1; }
[ -f "$REGISTRY_FILE" ] || { echo "ERROR: registry file not found at $REGISTRY_FILE"; exit 1; }

echo "Stopping all enabled services..."

# Loop through enabled services using jq
for yml_file in "$SERVICES_DIR"/*.yml; do
  project_name=$(basename "$yml_file" .yml)
  echo "Stopping stack: $yml_file (project: $project_name)"
  docker compose --env-file "$ENV_FILE" -f "$yml_file" -p "$project_name" down --remove-orphans || true
done

echo "All enabled services stopped."

