#!/bin/bash
# Prepares an environment (dev/stage/prod) for usage

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

log() {
    local GREEN='\033[1;32m'
    local RESET='\033[0m'
    echo -e "${GREEN}$*${RESET}"
}

# Source environment variables
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
log "Loaded Doppler environment variables." 

$SCRIPTS_DIR/doppler-save.sh
log "Saved Doppler secrets to /etc/homelab/.env."

# Ensure in homelab directory (sanity check)
cd $BASE_DIR || { echo "Error: homelab directory not found."; exit 1; }

# Set up directories
mkdir -p $LOGS_DIR
mkdir -p $BACKUP_DIR
mkdir -p $DATA_DIR
mkdir -p /etc/homelab
mkdir -p $DATA_DIR/tailscale
log "Created necessary directories." 

# Ensure execute permissions
chmod +x $BASE_DIR/scripts/*
log "Set execute permissions on scripts/*." 

# Setup GitHub access (dev/prod only)
if [ $ENVIRONMENT != "stage" ]; then
    if [ ! -f $SSH_PRIVATE_KEY ]; then
        ssh-keygen -t ed25519 -f $SSH_PRIVATE_KEY -N ""
    fi
    echo $GITHUB_PAT | gh auth login --with-token
    gh ssh-key add $SSH_PRIVATE_KEY.pub --title "$GITHUB_SSH_KEY_TITLE"
    ssh -T git@github.com 
    log "GitHub SSH key setup complete." 
else
    log "Skipping GitHub SSH key setup in $ENVIRONMENT environment." 
fi

# Set Git config
git config --global user.email "tbeidlershenk@gmail.com"
git config --global user.name "Tobias Beidler-Shenk"
git config --global user.token $GITHUB_PAT
log "Set global Git config." 

# Set SSH secrets (prod only)
if [ $ENVIRONMENT == "prod" ]; then
    gh secret set SSH_PRIVATE_KEY -b @"$SSH_PRIVATE_KEY" --repo "$REPO"
    gh secret set SSH_USER -b "$HOMELAB_USER" --repo "$REPO"
    gh secret set SSH_HOST -b "$HOSTNAME" --repo "$REPO"
    gh secret set TAILSCALE_CI_AUTHKEY -b "$TAILSCALE_CI_AUTHKEY" --repo "$REPO"
    log "Updated GitHub secrets for repository $REPO." 
else
    log "Skipping GitHub secrets setup in $ENVIRONMENT environment." 
fi

# Start Docker service
if ! systemctl is-active --quiet docker; then
    echo "Docker service is not running. Starting Docker..."
    systemctl enable docker
    systemctl start docker
fi
log "Docker daemon running." 

# Setup custom systemd services
cp $CONFIG_DIR/cloudflared.service /etc/systemd/system/cloudflared.service
cp $CONFIG_DIR/tailscaled.service /etc/systemd/system/tailscaled.service
cp $CONFIG_DIR/homeapi.service /etc/systemd/system/homeapi.service
cp $CONFIG_DIR/wrappers/cloudflared_start.sh /etc/homelab/cloudflared_start.sh
cp $CONFIG_DIR/wrappers/homeapi_start.sh /etc/homelab/homeapi_start.sh
cp $CONFIG_DIR/wrappers/tailscaled_start.sh /etc/homelab/tailscaled_start.sh
chmod +x /etc/homelab/cloudflared_start.sh
chmod +x /etc/homelab/homeapi_start.sh
chmod +x /etc/homelab/tailscaled_start.sh
systemctl daemon-reload
log "Setup custom systemd services."

# Enable Tailscale service
if [ $ENVIRONMENT == "stage" ]; then
    log "Skipping Tailscale up command in $ENVIRONMENT environment."
elif tailscale status &>/dev/null; then
    log "Skipping Tailscale up command as it is already running."
else
    tailscale up \
        --authkey "$TAILSCALE_AUTHKEY" \
        --ssh \
        --hostname "$TAILSCALE_HOSTNAME" \
        --accept-routes \
        --advertise-tags=tag:$ENVIRONMENT
    systemctl enable --now tailscaled
    systemctl start tailscaled
    log "Tailscale daemon running." 
fi

# Enable HomeAPI service
HOMEAPI_VENV_DIR="$BASE_DIR/homeapi/venv"
if [ ! -d "$HOMEAPI_VENV_DIR" ]; then
    python3 -m venv "$HOMEAPI_VENV_DIR"
    log "Created HomeAPI virtual environment."
else
    log "HomeAPI virtual environment exists."
fi
"$HOMEAPI_VENV_DIR/bin/pip" install --upgrade pip
"$HOMEAPI_VENV_DIR/bin/pip" install -r "$BASE_DIR/homeapi/requirements.txt"
systemctl enable --now homeapi
systemctl restart homeapi
log "HomeAPI service running."

# Enable Cloudflared service
if [ $ENVIRONMENT == "prod" ]; then
    systemctl enable --now cloudflared
    systemctl restart cloudflared
    log "Cloudflared service running."
else
    log "Skipping Cloudflared setup in $ENVIRONMENT environment."
fi