#!/bin/bash
# Installs dependencies to an environment (dev/stage/prod)

log() {
    local GREEN='\033[1;32m'
    local RESET='\033[0m'
    echo -e "${GREEN}$*${RESET}"
}

logerror() {
    local RED='\033[1;31m'
    local RESET='\033[0m'
    echo -e "${RED}$*${RESET}" >&2
}

# Install Doppler
curl -Ls https://cli.doppler.com/install.sh | sudo sh

# Source environment variables
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
log "Loaded Doppler environment variables." 

# Update system & install packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl
sudo apt install -y git
sudo apt install -y gh
sudo apt install -y yq
log "Installed apt packages." 

# Install Python 
sudo apt install python3-pip -y
sudo apt install python3-venv -y
log "Installed Python & Pip."

# Install Filen CLI
curl -sL https://filen.io/cli.sh | sudo bash
log "Installed Filen CLI."

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

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
log "Tailscale installation complete." 

# Install Cloudflared
if ! command -v cloudflared &> /dev/null; then
    wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i /tmp/cloudflared.deb
    rm /tmp/cloudflared.deb
fi
log "Cloudflared installed."

check() {
    if command -v "$1" &> /dev/null; then
        log "$1 installed: $($1 --version 2>/dev/null | head -n 1)"
    else
        logerror "$1 NOT installed"
    fi
}

check curl
check git
check gh
check yq
check python3
check pip3
check docker
check tailscale
check cloudflared
