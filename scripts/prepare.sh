#!/bin/bash

KEY_TITLE="homelab_$(date +%F)"
SSH_KEY="$HOME/.ssh/github_ed25519"
if [ -z "$GH_PAT" ]; then
    echo "Error: GH_PAT environment variable is not set."
    exit 1
fi

# Update system & install packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git gh

# Setup GitHub access
if [ ! -f $SSH_KEY ]; then
    ssh-keygen -t ed25519 -f $SSH_KEY -N ""
fi
echo $GH_PAT | gh auth login --with-token
gh ssh-key add $SSH_KEY.pub --title "$KEY_TITLE"
ssh -T git@github.com

# install docker
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

# start docker service
if ! systemctl is-active --quiet docker; then
    echo "Docker service is not running. Starting Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "Docker service is running."
fi