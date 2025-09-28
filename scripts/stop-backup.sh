#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
SERVICES_DIR="$BASE_DIR/services"
ENV_FILE="$BASE_DIR/${1:-.env}"
SKIP_SERVICES=("portainer" "tailscale" "cronicle")

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

echo "Stopping all services..."

for yml_file in "$SERVICES_DIR"/*.yml; do
  project_name=$(basename "$yml_file" .yml)

  if [[ " ${SKIP_SERVICES[*]} " == *" $project_name "* ]]; then
    echo "Skipping stack: $yml_file (project: $project_name)"
    continue
  fi

  echo "Stopping stack: $yml_file (project: $project_name)"
  docker compose --profile enabled --env-file "$ENV_FILE" -f "$yml_file" -p "$project_name" down --remove-orphans
done

echo "All services stopped."
