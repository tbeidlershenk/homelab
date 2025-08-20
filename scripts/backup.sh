#!/usr/bin/env bash
set -e
set -a
source "$HOME/homelab/.env"
set +a

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

# Rsync additional backup paths from .env variables
for backup_var in BACKUP_1 BACKUP_2 BACKUP_3; do
  src="${!backup_var}"
  if [ -n "$src" ] && [ -d "$src" ]; then
    echo "Backing up $src to $BACKUP_DIR/$(basename "$src")..."
    sudo rsync -av "$src/" "$BACKUP_DIR/$(basename "$src")/"
  elif [[ "$src" == *:* ]]; then
    echo "Backing up remote location $src to $BACKUP_DIR/$(basename "$src")..."
    sudo rsync -av "$src/" "$BACKUP_DIR/$(basename "$src")/"
  fi
  else
    echo "WARNING: $backup_var is not set or $src does not exist."
  fi
done

# sudo rsync -a --delete /var/lib/docker/volumes/ "$BACKUP_DIR/"

echo "Restarting stacks..."
bash "$HOME/homelab/start-services.sh"

echo "Backup completed successfully!"
echo "Backup directory: $BACKUP_DIR"
