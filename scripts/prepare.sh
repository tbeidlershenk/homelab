#!/bin/bash

# Source environment variables
ENV_FILE=${1:-.env}
[ ! -f "$ENV_FILE" ] && echo "Error: Environment file not found: $ENV_FILE" && exit 1 
set -a; source "$ENV_FILE"; set +a

# Verify required environment variables are set
[ -z "$GITHUB_PAT" ] && echo "Error: GITHUB_PAT is not set in $ENV_FILE" && exit 1 
[ -z "$REPO" ] && echo "Error: REPO is not set in $ENV_FILE" && exit 1 
[ -z "$EMAIL" ] && echo "Error: EMAIL is not set in $ENV_FILE" && exit 1 
[ -z "$USER" ] && echo "Error: USER is not set in $ENV_FILE" && exit 1
[ -z "$TAILSCALE_AUTHKEY" ] && echo "Error: TAILSCALE_AUTHKEY is not set in $ENV_FILE" && exit 1
[ -z "$TAILSCALE_HOSTNAME" ] && echo "Error: TAILSCALE_HOSTNAME is not set in $ENV_FILE" && exit 1
[ -z "$TAILSCALE_CI_AUTHKEY" ] && echo "Error: TAILSCALE_CI_AUTHKEY is not set in $ENV_FILE" && exit 1
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1

# Other variables
KEY_TITLE="homelab_$(date +%F)"
SSH_KEY="$HOME/.ssh/id_ed25519"
CRONICLE_SSH_DIR="$BASE_DIR/volumes/cronicle/ssh"

# Ensure in homelab directory (sanity check)
cd $BASE_DIR || { echo "Error: homelab directory not found."; exit 1; }

# Set up directories
mkdir -p $BASE_DIR/logs
sudo mkdir -p "$CRONICLE_SSH_DIR"

# Ensure execute permissions (sanity check)
chmod +x $BASE_DIR/scripts/*

# Update system & install packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git gh yq

# Setup GitHub access
if [ ! -f $SSH_KEY ]; then
    ssh-keygen -t ed25519 -f $SSH_KEY -N ""
fi
echo $GITHUB_PAT | gh auth login --with-token
gh ssh-key add $SSH_KEY.pub --title "$KEY_TITLE"
ssh -T git@github.com

# Set SSH secrets
gh secret set SSH_PRIVATE_KEY -b @"$SSH_KEY" --repo "$REPO"
gh secret set SSH_USER -b "$USER" --repo "$REPO"
gh secret set SSH_HOST -b "homelab" --repo "$REPO"
gh secret set TAILSCALE_CI_AUTHKEY -b "$TAILSCALE_CI_AUTHKEY" --repo "$REPO"
echo "Updated GitHub Actions secrets for repository $REPO."

# Set Git config
git config --global user.email "tbeidlershenk@gmail.com"
git config --global user.name "Tobias Beidler-Shenk"
git config --global user.token $GITHUB_PAT

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

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker using official get-docker.sh script..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker installed. You may need to re-login."
else
    echo "Docker is installed."
fi

# Start Docker service
if ! systemctl is-active --quiet docker; then
    echo "Docker service is not running. Starting Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "Docker service is running."
fi

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --authkey "$TAILSCALE_AUTHKEY" --hostname "$TAILSCALE_HOSTNAME" --accept-routes

# Enable Tailscale service
sudo systemctl enable --now tailscaled
