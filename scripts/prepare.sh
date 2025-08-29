#!/bin/bash

# update system
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git

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