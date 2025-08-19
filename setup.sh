#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/homelab"
ENV_FILE="$BASE_DIR/.env"
BACKUP_DRIVE="/mnt/backup"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found in $BASE_DIR"
  echo "Please create a .env file with the required environment variables before running this script."
  exit 1
fi

echo "Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git docker.io docker-compose

echo "Enabling Docker service..."
sudo systemctl enable --now docker

read -p "Do you want to restore volumes from backup before deploying stacks? [y/N]: " restore
if [[ "$restore" =~ ^[Yy]$ ]]; then
  read -p "Enter backup folder path: " backup_folder
  if [ -d "$backup_folder" ]; then
    echo "Restoring volumes from $backup_folder..."
    sudo rsync -a --delete "$backup_folder/" /var/lib/docker/volumes/
  else
    echo "Backup folder not found, skipping restore."
  fi
fi

echo "Starting Docker stacks..."
for d in "$BASE_DIR/services"; do
  echo "Deploying stack in $d"
  (docker-compose --env-file $ENV_FILE -f $d up -d)
done

echo "All stacks deployed!"
echo "Access Portainer at: http://localhost:9000"
