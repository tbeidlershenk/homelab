#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
SERVICES_DIR="$BASE_DIR/services"
ENV_FILE="$BASE_DIR/.env"

echo "Starting all homelab stacks..."
for yml_file in "$SERVICES_DIR"/*.yml; do
  [ -f "$yml_file" ] || continue
  echo "Starting stack using $yml_file"
  docker-compose --env-file "$ENV_FILE" -f "$yml_file" up -d
done

echo "All homelab stacks started."
