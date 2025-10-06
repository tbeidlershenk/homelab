#!/usr/bin/env bash
# Stops all enabled services in the registry file
set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

# Stop services enabled in registry file
echo "Stopping all enabled services..."
source "$script_context/helpers/stop_all.sh"

echo "All enabled services stopped."

