#!/usr/bin/env bash
# Backs up Docker volumes to a specified backup directory
set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
echo "Backing up Docker volumes to: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for backup..."
source "$script_context/helpers/pause_for_backup.sh"

# Log backup time
sudo mkdir -p "$LOGS_DIR"
sudo mkdir -p "$DATA_DIR"
echo "$TIMESTAMP - ran backup" >> "$LOGS_DIR/backup.log"
sudo rsync -av "$DATA_DIR/" "$BACKUP_DIR"

# Unpause services after backup
echo "Resuming paused services..."
source "$script_context/helpers/unpause_for_backup.sh"

echo "Backup completed successfully!"
echo "Backed up to directory: $BACKUP_DIR"

