#!/usr/bin/env bash
# Restores volumes from a backup
set -e
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

# Parse arguments
BACKUP_TYPE="local" 
while getopts "t:" opt; do
  case $opt in
    t) BACKUP_TYPE="$OPTARG" ;;
    *) echo "Usage: $0 -t <local,cloud>" >&2; exit 1 ;;
  esac
done

echo "Restoring Docker volumes from backup: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Stopping services for restore..."
source "$script_context/helpers/stop_all.sh"

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes at $VOLUMES_DIR. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    source "$script_context/helpers/start_enabled.sh"
    echo "Restore aborted." && exit 0
fi

# Log restore time
echo "$TIMESTAMP - ran restore" >> "$LOGS_DIR/backup.log"

# Stop Tailscale to avoid conflicts during restore
sudo systemctl stop tailscaled

# Restore volumes
if [ "$BACKUP_TYPE" == "local" ]; then
    echo "Restoring from local backup..."
    sudo rsync -av "$BACKUP_DIR/" "$DATA_DIR"
elif [ "$BACKUP_TYPE" == "cloud" ]; then
    echo "Restoring from cloud backup..."
    source "$script_context/helpers/filen_cloudtolocal.sh"
else
    echo "Error: Invalid backup type specified. Use 'local' or 'cloud'." && exit 1
fi

sudo systemctl start tailscaled

# Resume paused services
echo "Resuming enabled services..."
source "$script_context/helpers/start_enabled.sh"

echo "Restore completed successfully!"
echo "Restored from backup directory: $BACKUP_DIR"

