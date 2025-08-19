#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
SERVICES_DIR="$BASE_DIR/services"

echo "Stopping all stacks..."
for stack in "$SERVICES_DIR"/*; do
  if [ -f "$stack/docker-compose.yml" ]; then
    echo "Stopping stack in $stack"
    (cd "$stack" && docker-compose down)
  fi
done

echo "All stacks stopped."
