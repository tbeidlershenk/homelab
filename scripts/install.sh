#!/bin/bash
# Installs dependencies to an environment (dev/stage/prod)

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

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
curl -Ls https://cli.doppler.com/install.sh | sh

# Source environment variables
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
log "Loaded Doppler environment variables." 

# Update system & install packages
apt update
apt upgrade -y
apt install -y curl
apt install -y git
apt install -y gh
apt install -y yq
log "Installed apt packages." 

# Install Python 
apt install python3-pip -y
apt install python3-venv -y
log "Installed Python & Pip."

# Install Filen CLI
curl -sL https://filen.io/cli.sh | bash
log "Installed Filen CLI."

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker using official get-docker.sh script..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    usermod -aG docker $USER
    echo "You may need to re-login."
fi
log "Docker installation complete." 

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
log "Tailscale installation complete." 

# Install Cloudflared
if ! command -v cloudflared &> /dev/null; then
    wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i /tmp/cloudflared.deb
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
