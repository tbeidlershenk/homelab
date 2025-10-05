#!/bin/bash
# Prepares an environment (dev/stage/prod) for usage

log() {
    local GREEN='\033[1;32m'
    local RESET='\033[0m'
    echo -e "${GREEN}$*${RESET}"
}

# Install Doppler
curl -Ls https://cli.doppler.com/install.sh | sudo sh

# Source environment variables
source "$(dirname "${BASH_SOURCE[0]}")/doppler-get.sh"
log "Loaded Doppler environment variables." 

# Verify required environment variables are set
[ -z "$GITHUB_PAT" ] && echo "Error: GITHUB_PAT is not set in $ENV_FILE" && exit 1 
[ -z "$REPO" ] && echo "Error: REPO is not set in $ENV_FILE" && exit 1 
[ -z "$EMAIL" ] && echo "Error: EMAIL is not set in $ENV_FILE" && exit 1 
[ -z "$USER" ] && echo "Error: USER is not set in $ENV_FILE" && exit 1
[ -z "$ENVIRONMENT" ] && echo "Error: ENVIRONMENT is not set in $ENV_FILE" && exit 1
[ -z "$TAILSCALE_AUTHKEY" ] && echo "Error: TAILSCALE_AUTHKEY is not set in $ENV_FILE" && exit 1
[ -z "$TAILSCALE_HOSTNAME" ] && echo "Error: TAILSCALE_HOSTNAME is not set in $ENV_FILE" && exit 1
[ -z "$TAILSCALE_CI_AUTHKEY" ] && echo "Error: TAILSCALE_CI_AUTHKEY is not set in $ENV_FILE" && exit 1
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1

# Other variables
KEY_TITLE="homelab_$(date +%F)"
SSH_KEY="$HOME/.ssh/id_ed25519"
CRONICLE_SSH_DIR="$BASE_DIR/volumes/cronicle/ssh"
TAILSCALE_STATE_DIR="$BASE_DIR/volumes/tailscale"

# Ensure in homelab directory (sanity check)
cd $BASE_DIR || { echo "Error: homelab directory not found."; exit 1; }

# Set up directories
mkdir -p $BASE_DIR/logs
mkdir -p $BASE_DIR/backup
mkdir -p $BASE_DIR/volumes
sudo mkdir -p $TAILSCALE_STATE_DIR
sudo mkdir -p "$CRONICLE_SSH_DIR"
log "Created necessary directories." 

# Ensure execute permissions
chmod +x $BASE_DIR/scripts/*
log "Set execute permissions on scripts/*." 

# Update system & install packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git gh yq
log "Installed apt packages." 

curl -sL https://filen.io/cli.sh | sudo bash
log "Installed Filen CLI."

# Setup GitHub access
if [ ! -f $SSH_KEY ]; then
    ssh-keygen -t ed25519 -f $SSH_KEY -N ""
fi
echo $GITHUB_PAT | gh auth login --with-token
gh ssh-key add $SSH_KEY.pub --title "$KEY_TITLE"
ssh -T git@github.com 
log "GitHub SSH key setup complete." 

# Set SSH secrets
gh secret set SSH_PRIVATE_KEY -b @"$SSH_KEY" --repo "$REPO"
gh secret set SSH_USER -b "$USER" --repo "$REPO"
gh secret set SSH_HOST -b "homelab" --repo "$REPO"
gh secret set TAILSCALE_CI_AUTHKEY -b "$TAILSCALE_CI_AUTHKEY" --repo "$REPO"
log "Updated GitHub secrets for repository $REPO." 

# Set Git config
git config --global user.email "tbeidlershenk@gmail.com"
git config --global user.name "Tobias Beidler-Shenk"
git config --global user.token $GITHUB_PAT
log "Set global Git config." 

# Generate a dedicated SSH key for Cronicle if it doesn't exist
CRONICLE_KEY="$CRONICLE_SSH_DIR/id_ed25519"
if [ ! -f "$CRONICLE_KEY" ]; then
    sudo ssh-keygen -t ed25519 -f "$CRONICLE_KEY" -N ""
    sudo chmod 600 "$CRONICLE_KEY"
    echo "Generated SSH key for Cronicle container:"
    sudo cat "${CRONICLE_KEY}.pub"
fi

# Add the public key to the host's authorized_keys (allows container SSH)
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
grep -qxF "$(cat ${CRONICLE_KEY}.pub)" "$AUTHORIZED_KEYS" || \
    sudo cat "${CRONICLE_KEY}.pub" >> "$AUTHORIZED_KEYS"
echo "Added Cronicle container public key to host's authorized_keys."
log "Container SSH access complete." 

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker using official get-docker.sh script..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "You may need to re-login."
fi
log "Docker installation complete." 

# Start Docker service
if ! systemctl is-active --quiet docker; then
    echo "Docker service is not running. Starting Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
fi
log "Docker daemon running." 

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
log "Tailscale installation complete." 

# Enable Tailscale service
sudo mkdir -p /etc/systemd/system/tailscaled.service.d
sudo tee /etc/systemd/system/tailscaled.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/tailscaled --statedir=$TAILSCALE_STATE_DIR
EOF
log "Configured Tailscale systemd service."

sudo tailscale up \
    --authkey "$TAILSCALE_AUTHKEY" \
    --ssh \
    --hostname "$TAILSCALE_HOSTNAME" \
    --accept-routes \
    --advertise-tags=tag:$ENVIRONMENT
sudo systemctl enable --now tailscaled
sudo systemctl restart tailscaled
log "Tailscale daemon running." 
