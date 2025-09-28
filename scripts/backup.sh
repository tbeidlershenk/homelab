#!/usr/bin/env bash
set -e

# Source environment variables
ENV_FILE=${1:-.env}
[ ! -f "$ENV_FILE" ] && echo "Error: Environment file not found: $ENV_FILE" && exit 1 
set -a; source "$ENV_FILE"; set +a

# Verify required environment variables are set
[ -z "$BASE_DIR" ] && echo "Error: BASE_DIR is not set in $ENV_FILE" && exit 1
[ -z "$REGISTRY_FILE" ] && echo "Error: REGISTRY_FILE is not set in $ENV_FILE" && exit 1
[ -z "$BACKUP_DIR" ] && echo "Error: BACKUP_DIR is not set in $ENV_FILE" && exit 1
[ ! -d "$BACKUP_DIR" ] && echo "ERROR: Backup directory not found at $BACKUP_DIR" && exit 1

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
SCRIPTS_DIR="$BASE_DIR/scripts"
VOLUMES_DIR="$BASE_DIR/volumes"
LOGS_DIR="$BASE_DIR/logs"

echo "Backing up Docker volumes to: $BACKUP_DIR"

# Pause services marked pause_on_backup: true
echo "Pausing services for backup..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Pausing $project_name..."
  docker compose --env-file $ENV_FILE -f "$yml_file" -p "$project_name" pause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$REGISTRY_FILE")

# Log backup time
echo "$TIMESTAMP - ran backup" >> "$LOGS_DIR/backup.log"

# Ensure backup directory exists
sudo mkdir -p "$BACKUP_DIR"

# Run rsync backup
sudo rsync -av "$VOLUMES_DIR/" "$BACKUP_DIR"

# Unpause services after backup
echo "Resuming paused services..."
while IFS= read -r yml_file; do
  project_name=$(basename "$yml_file" .yml)
  echo "Resuming $project_name..."
  docker compose --env-file $ENV_FILE -f "$yml_file" -p "$project_name" unpause || true
done < <(jq -r '.services[] | select(.enabled==true and .pause_on_backup==true) | .path' "$REGISTRY_FILE")

echo "Backup completed successfully!"
echo "Backed up to directory: $BACKUP_DIR"

