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
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
log "Loaded Doppler environment variables." 

# Verify paths exist
if [ ! -f "$REGISTRY_PATH" ]; then
    echo "REGISTRY_FILE not found at $REGISTRY_PATH. Creating from default."
    sudo cp "$BASE_DIR/config/default_registry.json" "$REGISTRY_PATH"
    log "Copied default registry to $REGISTRY_PATH."
fi

# Ensure in homelab directory (sanity check)
cd $BASE_DIR || { echo "Error: homelab directory not found."; exit 1; }

# Set up directories
mkdir -p $LOGS_DIR
mkdir -p $BACKUP_DIR
mkdir -p $DATA_DIR
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
    gh secret set SSH_USER -b "$USER" --repo "$REPO"
    gh secret set SSH_HOST -b "$HOSTNAME" --repo "$REPO"
    gh secret set TAILSCALE_CI_AUTHKEY -b "$TAILSCALE_CI_AUTHKEY" --repo "$REPO"
    log "Updated GitHub secrets for repository $REPO." 
else
    log "Skipping GitHub secrets setup in $ENVIRONMENT environment." 
fi

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

if [ $ENVIRONMENT != "stage" ]; then
    sudo tailscale up \
        --authkey "$TAILSCALE_AUTHKEY" \
        --ssh \
        --hostname "$TAILSCALE_HOSTNAME" \
        --accept-routes \
        --advertise-tags=tag:$ENVIRONMENT
    sudo systemctl enable --now tailscaled
    sudo systemctl restart tailscaled
    log "Tailscale daemon running." 
else
    log "Skipping Tailscale up command in $ENVIRONMENT environment."
fi
