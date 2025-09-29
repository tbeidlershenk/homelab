#!/usr/bin/env bash
set -e

# Source environment variables
ENV_FILE=${1:-.env}
[ ! -f "$ENV_FILE" ] && echo "Error: Environment file not found: $ENV_FILE" && exit 1 
set -a; source "$ENV_FILE"; set +a

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set in $ENV_FILE" && exit 1
[ -z "$HEALTHCHECK_TIMEOUT" ] && HEALTHCHECK_TIMEOUT=300
[ -z "$HEALTHCHECK_INTERVAL" ] && HEALTHCHECK_INTERVAL=10

# Other variables
SERVICES_DIR="$BASE_DIR/services"

echo "Checking health of all enabled services with healthchecks..."

# Get all enabled services with healthcheck=true from the registry
services=$(jq -r '.services[] | select(.enabled==true and .healthcheck==true) | .path' "$REGISTRY_FILE")

for yml_file in $services; do
    project_name=$(basename "$yml_file" .yml)
    echo "Waiting for containers in stack '$project_name' to become healthy..."

    # Get container IDs for this stack
    containers=$(docker compose --env-file "$ENV_FILE" -f "$SERVICES_DIR/$yml_file" -p "$project_name" ps -q)
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

        if [ "$elapsed" -ge "$HEALTHCHECK_TIMEOUT" ]; then
            echo "ERROR: The following containers in '$project_name' are still unhealthy after $HEALTHCHECK_TIMEOUT seconds:"
            echo "$unhealthy"
            exit 1
        fi

        sleep $HEALTHCHECK_INTERVAL
        elapsed=$((elapsed + HEALTHCHECK_INTERVAL))
    done
done

echo "All enabled services with healthchecks are healthy!"

