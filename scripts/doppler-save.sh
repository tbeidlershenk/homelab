#!/usr/bin/env bash
# Acts as a wrapper to inject secrets directly into the environment

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
if [ -f $ENV_FILE ]; then
    set -a; source $ENV_FILE; set +a
fi

# Check for Doppler variables
[ -z "$DOPPLER_PROJECT" ] && echo "Error: DOPPLER_PROJECT is not configured." && exit 1
[ -z "$DOPPLER_CONFIG" ] && echo "Error: DOPPLER_CONFIG is not configured." && exit 1
[ -z "$DOPPLER_TOKEN" ] && echo "Error: DOPPLER_TOKEN is not configured." && exit 1

# Save to .env file for systemd services
echo "Environment: $DOPPLER_CONFIG"
echo "Downloading secrets from PROJECT: $DOPPLER_PROJECT, CONFIG: $DOPPLER_CONFIG..."
doppler secrets download \
    --token "$DOPPLER_TOKEN" \
    --project "$DOPPLER_PROJECT" \
    --config "$DOPPLER_CONFIG" \
    --no-file \
    --format env | tee /etc/homelab/.env > /dev/null
echo "Saved secrets to configuration file."