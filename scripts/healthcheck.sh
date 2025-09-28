#!/usr/bin/env bash
set -e

HOMELAB_DIR="$HOME/homelab"
REGISTRY_FILE="$HOMELAB_DIR/config/registry.json"
TIMEOUT=120          # max wait time in seconds
SLEEP_INTERVAL=5     # seconds between checks
ENV_FILE="$HOMELAB_DIR/${1:-.env}"

echo "Checking health of all enabled services with healthchecks..."

# Get all enabled services with healthcheck=true from the registry
services=$(jq -r '.services[] | select(.enabled==true and .healthcheck==true) | .path' "$REGISTRY_FILE")

for yml_file in $services; do
    project_name=$(basename "$yml_file" .yml)
    echo "Waiting for containers in stack '$project_name' to become healthy..."

    # Get container IDs for this stack
    containers=$(docker compose --env-file "$ENV_FILE" -f "$yml_file" -p "$project_name" ps -q)
    if [ -z "$containers" ]; then
        echo "No containers found for $project_name, skipping."
        continue
    fi

    elapsed=0
    while true; do
        unhealthy=""
        for container in $containers; do
            status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null)
            if [ "$status" != "healthy" ]; then
                unhealthy="$unhealthy $container($status)"
            fi
        done

        if [ -z "$unhealthy" ]; then
            echo "All containers in '$project_name' are healthy."
            break
        fi

        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "ERROR: The following containers in '$project_name' are still unhealthy after $TIMEOUT seconds:"
            echo "$unhealthy"
            exit 1
        fi

        sleep $SLEEP_INTERVAL
        elapsed=$((elapsed + SLEEP_INTERVAL))
    done
done

echo "All enabled services with healthchecks are healthy!"

