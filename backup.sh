#!/usr/bin/env bash
set -e

BACKUP_DRIVE="/mnt/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_DRIVE/docker_volumes_backup_$TIMESTAMP"

if [ ! -d "$BACKUP_DRIVE" ]; then
  echo "ERROR: Backup drive not found at $BACKUP_DRIVE"
  exit 1
fi

echo "Stopping stacks for backup..."
bash "$HOME/homelab/stop-services.sh"

echo "Backing up Docker volumes to $BACKUP_DIR..."
sudo mkdir -p "$BACKUP_DIR"
sudo tar -czvf backup/homelab_backup.tar.gz -C /var/lib/docker/volumes . 

# Extract:
# sudo tar -xzvf ~/backup/homelab_backup.tar.gz -C /var/lib/docker/volumes

# sudo rsync -a --delete /var/lib/docker/volumes/ "$BACKUP_DIR/"

echo "Restarting stacks..."
bash "$HOME/homelab/start-services.sh"

echo "Backup completed successfully!"
echo "Backup directory: $BACKUP_DIR"
