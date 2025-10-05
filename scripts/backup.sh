#!/usr/bin/env bash
set -e

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

echo "Backing up Docker volumes to: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for backup..."
while IFS= read -r yml_file; do
    project_name=$(basename "$yml_file" .yml)
    echo "Pausing $project_name..."
    docker compose -f "$SERVICES_DIR/$yml_file" -p "$project_name" pause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$BASE_DIR/$REGISTRY_FILE")

# Log backup time
echo "$TIMESTAMP - ran backup" >> "$LOGS_DIR/backup.log"

# Ensure backup directory exists
sudo mkdir -p "$BACKUP_DIR"

# Run rsync backup
sudo rsync -av "$VOLUMES_DIR/" "$BACKUP_DIR"

for yml_file in $(jq -r '.services[] | select(.cloud_backup==true) | .path' "$BASE_DIR/$REGISTRY_FILE"); do
    project_name=$(basename "$yml_file" .yml)
    echo "Backing up $project_name to Filen..."
    filen mkdir /$project_name \
        --email "$FILEN_EMAIL" \
        --password "$FILEN_PASSWORD"
    sudo -E env "PATH=$PATH" filen sync $VOLUMES_DIR/$project_name:localToCloud:/$project_name \
        --email "$FILEN_EMAIL" \
        --password "$FILEN_PASSWORD"
done

# Unpause services after backup
echo "Resuming paused services..."
while IFS= read -r yml_file; do
    project_name=$(basename "$yml_file" .yml)
    echo "Resuming $project_name..."
    docker compose -f "$SERVICES_DIR/$yml_file" -p "$project_name" unpause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$BASE_DIR/$REGISTRY_FILE")

echo "Backup completed successfully!"
echo "Backed up to directory: $BACKUP_DIR"

