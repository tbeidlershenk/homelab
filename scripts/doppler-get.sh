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
# Download as JSON and have Python emit shell-quoted assignments, so secret
# values are treated as data and never executed (no $(...) / backtick expansion).
secrets_json="$(doppler secrets download \
    --token "$DOPPLER_TOKEN" \
    --project "$DOPPLER_PROJECT" \
    --config "$DOPPLER_CONFIG" \
    --no-file \
    --format json)" || { echo "Error: failed to download secrets from Doppler."; exit 1; }
secrets_sh="$(python3 -c '
import json, re, shlex, sys
for k, v in json.load(sys.stdin).items():
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k):
        print(f"export {k}={shlex.quote(str(v))}")
' <<< "$secrets_json")" || { echo "Error: failed to parse Doppler secrets."; exit 1; }
eval "$secrets_sh"
unset secrets_json secrets_sh
echo "Injected secrets into environment."

# Verify required environment variables are set
[ -z "$TAILSCALE_AUTHKEY" ] && echo "Error: TAILSCALE_AUTHKEY is not set" && exit 1
[ -z "$TAILSCALE_HOSTNAME" ] && echo "Error: TAILSCALE_HOSTNAME is not set" && exit 1
[ -z "$TAILSCALE_CI_AUTHKEY" ] && echo "Error: TAILSCALE_CI_AUTHKEY is not set" && exit 1
[ -z "$GITHUB_PAT" ] && echo "Error: GITHUB_PAT is not set" && exit 1 
[ -z "$SIYUAN_ACCESS_AUTH_CODE" ] && echo "Error: SIYUAN_ACCESS_AUTH_CODE is not set" && exit 1
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set" && exit 1
[ -z "$HOSTNAME" ] && echo "Error: HOSTNAME is not set" && exit 1
[ -z "$REPO" ] && echo "Error: REPO is not set" && exit 1 
[ -z "$EMAIL" ] && echo "Error: EMAIL is not set" && exit 1 
[ -z "$HOMELAB_USER" ] && echo "Error: HOMELAB_USER is not set" && exit 1

set -a

# Directories
CONFIG_DIR="$BASE_DIR/config"
SCRIPTS_DIR="$BASE_DIR/scripts"
SERVICES_DIR="$BASE_DIR/services"
LOGS_DIR="$BASE_DIR/logs"

# Other variables
TIMESTAMP="$(date +"%Y-%m-%d %H:%M:%S")"
GITHUB_SSH_KEY_TITLE="$HOSTNAME"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
SSH_PRIVATE_KEY="$HOME/.ssh/id_ed25519"
ENVIRONMENT="$DOPPLER_CONFIG"

set +a

echo "Done."
