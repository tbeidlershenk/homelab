#!/usr/bin/env bash
# Checks health status of services with the "healthcheck" flag

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

echo "Checking health of all enabled services with healthchecks..."

# Get all enabled services with healthcheck=true from the registry
services=$(jq -r '.[] | select(.enabled==true and .healthcheck==true) | .name' "$REGISTRY_PATH")

for name in $services; do
    echo "Waiting for containers in stack '$name' to become healthy..."

    # Get container IDs for this stack
    containers=$(docker compose -f "$SERVICES_DIR/$name.yml" -p "$name" ps -q)
    if [ -z "$containers" ]; then
        echo "No containers found for $name, skipping."
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
            echo "All containers in '$name' are healthy."
            break
        fi

        if [ "$elapsed" -ge "$HEALTHCHECK_TIMEOUT" ]; then
            echo "ERROR: The following containers in '$name' are still unhealthy after $HEALTHCHECK_TIMEOUT seconds:"
            echo "$unhealthy"
            exit 1
        fi

        sleep $HEALTHCHECK_INTERVAL
        elapsed=$((elapsed + HEALTHCHECK_INTERVAL))
    done
done

echo "All enabled services with healthchecks are healthy!"

