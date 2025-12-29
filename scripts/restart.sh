#!/bin/bash
# Restarts all running Docker containers

script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

# ensure dockge is running
docker compose -f $BASE_DIR/dockge/compose.yml up -d
echo "Started Dockge service."

# restart all other containers
docker ps -q | xargs -r docker restart
echo "Restarted all running Docker containers."