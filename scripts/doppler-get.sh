#!/usr/bin/env bash
# Acts as a wrapper to inject secrets directly into the environment

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"

# If we have a .env file we are in development environment
if [ -f $ENV_FILE ]; then
    set -a; source $ENV_FILE; set +a
fi

# Check for Doppler variables
[ -z "$DOPPLER_PROJECT" ] && echo "Error: DOPPLER_PROJECT is not configured." && exit 1
[ -z "$DOPPLER_CONFIG" ] && echo "Error: DOPPLER_CONFIG is not configured." && exit 1
[ -z "$DOPPLER_TOKEN" ] && echo "Error: DOPPLER_TOKEN is not configured." && exit 1
echo "Environment: $DOPPLER_CONFIG"

# Inject secrets into environment
echo "Downloading secrets from PROJECT: $DOPPLER_PROJECT, CONFIG: $DOPPLER_CONFIG..."
eval "$(doppler secrets download \
    --token "$DOPPLER_TOKEN" \
    --project $DOPPLER_PROJECT \
    --config $DOPPLER_CONFIG \
    --no-file \
    --format env \
    | sed 's/^/export /')"
echo "Done."