#!/usr/bin/env bash
# Acts as a wrapper to inject secrets directly into the environment

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
if [ -f $ENV_FILE ]; then
    set -a; source $ENV_FILE; set +a
fi

# Check for Doppler variables
[ -z "$DOPPLER_PROJECT" ] && echo "Error: DOPPLER_PROJECT is not configured." && exit 1
[ -z "$DOPPLER_CONFIG" ] && echo "Error: DOPPLER_CONFIG is not configured." && exit 1
[ -z "$DOPPLER_TOKEN" ] && echo "Error: DOPPLER_TOKEN is not configured." && exit 1

# Inject secrets into environment
echo "Environment: $DOPPLER_CONFIG"
echo "Downloading secrets from PROJECT: $DOPPLER_PROJECT, CONFIG: $DOPPLER_CONFIG..."
eval "$(doppler secrets download \
    --token "$DOPPLER_TOKEN" \
    --project "$DOPPLER_PROJECT" \
    --config "$DOPPLER_CONFIG" \
    --no-file \
    --format env \
    | sed 's/^/export /')"
echo "Injected secrets into environment."

# Verify required environment variables are set
[ -z "$TAILSCALE_AUTHKEY" ] && echo "Error: TAILSCALE_AUTHKEY is not set" && exit 1
[ -z "$TAILSCALE_HOSTNAME" ] && echo "Error: TAILSCALE_HOSTNAME is not set" && exit 1
[ -z "$TAILSCALE_CI_AUTHKEY" ] && echo "Error: TAILSCALE_CI_AUTHKEY is not set" && exit 1
[ -z "$GITHUB_PAT" ] && echo "Error: GITHUB_PAT is not set" && exit 1 
[ -z "$FILEN_EMAIL" ] && echo "Error: FILEN_EMAIL is not set" && exit 1
[ -z "$FILEN_PASSWORD" ] && echo "Error: FILEN_PASSWORD is not set" && exit 1
[ -z "$SIYUAN_ACCESS_AUTH_CODE" ] && echo "Error: SIYUAN_ACCESS_AUTH_CODE is not set" && exit 1
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set" && exit 1
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set" && exit 1
[ -z "$HOSTNAME" ] && echo "Error: HOSTNAME is not set" && exit 1 
[ -z "$REPO" ] && echo "Error: REPO is not set" && exit 1 
[ -z "$EMAIL" ] && echo "Error: EMAIL is not set" && exit 1 
[ -z "$HOMELAB_USER" ] && echo "Error: USER is not set" && exit 1

set -a

# Directories
CONFIG_DIR="$BASE_DIR/config"
TEST_CONFIG_DIR="$BASE_DIR/config/test"
SCRIPTS_DIR="$BASE_DIR/scripts"
SERVICES_DIR="$BASE_DIR/services"
DATA_DIR="$BASE_DIR/data"
BACKUP_DIR="$BASE_DIR/backup"
LOGS_DIR="$BASE_DIR/logs"

# Other variables
TIMESTAMP="$(date +"%Y-%m-%d %H:%M:%S")"
GITHUB_SSH_KEY_TITLE="$HOSTNAME"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
SSH_PRIVATE_KEY="$HOME/.ssh/id_ed25519"
ENVIRONMENT="$DOPPLER_CONFIG"

set +a

echo "Done."