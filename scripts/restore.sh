#!/usr/bin/env bash
# Restores volumes from a backup
set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
echo "Restoring Docker volumes from backup: $BACKUP_DIR"

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes at $VOLUMES_DIR. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    echo "Restore aborted." && exit 0
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory $BACKUP_DIR does not exist. Aborting." && exit 1
fi

# Pause services marked pause_on_backup: true
echo "Stopping services for restore..."
source "$script_context/helpers/stop_all.sh"
sudo systemctl stop tailscaled

# Restore volumes
sudo mkdir -p "$LOGS_DIR"
echo "$TIMESTAMP - ran restore" >> "$LOGS_DIR/backup.log"
sudo rsync -av "$BACKUP_DIR/" "$DATA_DIR"

# Resume paused services
echo "Resuming enabled services..."
sudo systemctl start tailscaled
source "$script_context/helpers/start_enabled.sh"

echo "Restore completed successfully!"
echo "Restored from backup directory: $BACKUP_DIR"

