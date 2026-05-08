#!/bin/bash
# Restarts all running Docker containers

script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
sudo "$script_context/doppler-save.sh"

# ensure portainer is running
docker compose -f $BASE_DIR/portainer/compose.yml up -d
echo "Started Portainer service."

# restart all other containers
docker ps -q | xargs -r docker restart
echo "Restarted all running Docker containers."
