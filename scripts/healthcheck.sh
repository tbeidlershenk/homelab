#!/bin/bash
# Wait for all Docker containers to become healthy, fail if timeout

TIMEOUT=60  # seconds
INTERVAL=2  # seconds between checks

# Get all running container IDs
CONTAINERS=$(docker ps -q)

if [ -z "$CONTAINERS" ]; then
    echo "No running containers."
    exit 1
fi

echo "Waiting for containers to become healthy..."

SECONDS_ELAPSED=0
while [ $SECONDS_ELAPSED -lt $TIMEOUT ]; do
    UNHEALTHY=0
    for CID in $CONTAINERS; do
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CID 2>/dev/null)
        if [ "$STATUS" != "healthy" ]; then
            UNHEALTHY=1
            break
        fi
    done

    if [ $UNHEALTHY -eq 0 ]; then
        echo "All containers are healthy!"
        exit 0
    fi

    sleep $INTERVAL
    SECONDS_ELAPSED=$((SECONDS_ELAPSED + INTERVAL))
done

echo "Some containers are unhealthy after $TIMEOUT seconds:"
docker ps --filter "health=unhealthy"
exit 1
