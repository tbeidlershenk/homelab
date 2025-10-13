#!/usr/bin/env bash
# Starts all enabled services in the registry file
set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

echo "Stopping all services..."
source "$script_context/helpers/stop_all.sh"

# Start services enabled in registry file
echo "Starting all enabled services..."
source "$script_context/helpers/start_enabled.sh"

echo "All enabled services started."

