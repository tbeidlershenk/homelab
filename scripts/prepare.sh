#!/bin/bash

REPO="tbeidlershenk/homelab"
EMAIL="tbeidlershenk@gmail.com"
NAME="Tobias Beidler-Shenk"

KEY_TITLE="homelab_$(date +%F)"
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -z "$GH_PAT" ]; then
    echo "Error: GH_PAT environment variable is not set."
    exit 1
fi

# Ensure in homelab directory (sanity check)
cd $HOME/homelab || { echo "Error: homelab directory not found."; exit 1; }

# Set up directories
mkdir -p $HOME/homelab/logs

# Ensure execute permissions (sanity check)
chmod +x scripts/*

# Update system & install packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git gh yq

# Setup GitHub access
if [ ! -f $SSH_KEY ]; then
    ssh-keygen -t ed25519 -f $SSH_KEY -N ""
fi
echo $GH_PAT | gh auth login --with-token
gh ssh-key add $SSH_KEY.pub --title "$KEY_TITLE"
ssh -T git@github.com

# Set SSH secrets
gh secret set SSH_PRIVATE_KEY -b @"$SSH_KEY" --repo "$REPO"
gh secret set SSH_USER -b "$USER" --repo "$REPO"
gh secret set SSH_HOST -b "your.server.com" --repo "$REPO"
echo "Updated GitHub Actions secrets for repository $REPO."

# Set Git config
git config --global user.email "tbeidlershenk@gmail.com"
git config --global user.name "Tobias Beidler-Shenk"
git config --global user.token $GH_PAT

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
