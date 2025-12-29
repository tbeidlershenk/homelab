#!/usr/bin/env bash
# Backs up Docker volumes to a specified backup directory
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"
echo "Backing up Docker volumes to: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for backup..."
docker ps \
  --filter "label=pause_for_backup=true" \
  -q | xargs -r docker stop

# Log backup time
mkdir -p "$LOGS_DIR"
mkdir -p "$DATA_DIR"
echo "$TIMESTAMP - ran backup" >> "$LOGS_DIR/backup.log"
rsync -av "$DATA_DIR/" "$BACKUP_DIR"

# Unpause services after backup
echo "Resuming paused services..."
docker ps -a \
  --filter "label=pause_for_backup=true" \
  -q | xargs -r docker start

echo "Backup completed successfully!"
echo "Backed up to directory: $BACKUP_DIR"

