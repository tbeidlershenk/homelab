#!/usr/bin/env bash
# Restores volumes from a backup
set -e

# Parse arguments
BACKUP_TYPE="local" 
while getopts "t:" opt; do
  case $opt in
    t) BACKUP_TYPE="$OPTARG" ;;
    *) echo "Usage: $0 -t <local,cloud>" >&2; exit 1 ;;
  esac
done

# Source environment variables
source "$(dirname "${BASH_SOURCE[0]}")/doppler-get.sh"

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set in $ENV_FILE" && exit 1
[ -z "$FILEN_EMAIL" ] && echo "Error: FILEN_EMAIL is not set in $ENV_FILE" && exit 1
[ -z "$FILEN_PASSWORD" ] && echo "Error: FILEN_PASSWORD is not set in $ENV_FILE" && exit 1

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
SCRIPTS_DIR="$BASE_DIR/scripts"
SERVICES_DIR="$BASE_DIR/services"
VOLUMES_DIR="$BASE_DIR/volumes"
BACKUP_DIR="$BASE_DIR/backup"
LOGS_DIR="$BASE_DIR/logs"

echo "Restoring Docker volumes from backup: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for restore..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Pausing $project_name..."
  docker compose -f "$SERVICES_DIR/$yml_file" -p "$project_name" pause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$BASE_DIR/$REGISTRY_FILE")

# Confirm before overwriting volumes
read -p "WARNING: This will overwrite existing Docker volumes at $VOLUMES_DIR. Proceed? (confirm YES): " confirm_restore
if [[ "$confirm_restore" != "YES" ]]; then
    echo "Restore aborted." && exit 0
fi

# Log restore time
echo "$TIMESTAMP - ran restore" >> "$LOGS_DIR/backup.log"

# Restore volumes
if [ "$BACKUP_TYPE" == "local" ]; then
    echo "Restoring from local backup..."
    sudo rsync -av "$BACKUP_DIR/" "$VOLUMES_DIR"
elif [ "$BACKUP_TYPE" == "cloud" ]; then
    echo "Restoring from cloud backup..."
    for yml_file in $(jq -r '.services[] | select(.cloud_backup==true) | .path' "$BASE_DIR/$REGISTRY_FILE"); do
        project_name=$(basename "$yml_file" .yml)
        echo "Restoring $project_name from Filen..."
        sudo filen -E env "PATH=$PATH" sync /$project_name:cloudToLocal:$VOLUMES_DIR/$project_name \
            --email "$FILEN_EMAIL" \
            --password "$FILEN_PASSWORD"
    done
else
    echo "Error: Invalid backup type specified. Use 'local' or 'cloud'." && exit 1
fi

# Resume paused services
echo "Resuming paused services..."
while IFS= read -r yml_file; do
    project_name=$(basename "$yml_file" .yml)
    echo "Resuming $project_name..."
    docker compose -f "$SERVICES_DIR/$yml_file" -p "$project_name" unpause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$BASE_DIR/$REGISTRY_FILE")

echo "Restore completed successfully!"
echo "Restored from backup directory: $BACKUP_DIR"

