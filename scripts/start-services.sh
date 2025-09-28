#!/usr/bin/env bash
set -e

echo "DEBUG: args = $@"
echo "DEBUG: ENV_FILE=$ENV_FILE"

HOMELAB_DIR="$HOME/homelab"

# Defaults
ENV_FILE="$HOMELAB_DIR/.env"
REGISTRY_FILE="$HOMELAB_DIR/config/registry.json"

# Parse flags
while getopts "e:r:" opt; do
  case $opt in
    e) ENV_FILE="$OPTARG" ;;
    r) REGISTRY_FILE="$OPTARG" ;;
    *) echo "Usage: $0 [-e env_file] [-r registry_file]"; exit 1 ;;
  esac
done

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

