#!/usr/bin/env bash
set -e

HOMELAB_DIR="$HOME/homelab"
SERVICES_DIR="$HOMELAB_DIR/services"

# Defaults
ENV_FILE="$HOMELAB_DIR/.env"
REGISTRY_FILE="$HOMELAB_DIR/config/registry.json"

# Parse flags
while getopts "d:e:r:" opt; do
  case $opt in
    e) ENV_FILE="$OPTARG" ;;
    r) REGISTRY_FILE="$OPTARG" ;;
    *) echo "Usage: $0 [-e env_file] [-r registry_file]"; exit 1 ;;
  esac
done

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

