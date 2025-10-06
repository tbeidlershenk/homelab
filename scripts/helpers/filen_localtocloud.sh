# Docker volumes
for yml_file in $(jq -r '.[] | select(.cloud_backup==true) | .path' "$REGISTRY_PATH"); do
    project_name=$(basename "$yml_file" .yml)
    echo "Backing up $project_name to Filen..."
    sudo -E env "PATH=$PATH" filen mkdir /$project_name \
        --email "$FILEN_EMAIL" \
        --password "$FILEN_PASSWORD"
    sudo -E env "PATH=$PATH" filen sync $BACKUP_DIR/$project_name:localToCloud:/$project_name \
        --email "$FILEN_EMAIL" \
        --password "$FILEN_PASSWORD"
done

# Tailscale state backup
sudo -E env "PATH=$PATH" filen mkdir /tailscale \
    --email "$FILEN_EMAIL" \
    --password "$FILEN_PASSWORD"
sudo -E env "PATH=$PATH" filen sync $BACKUP_DIR/tailscale:localToCloud:/tailscale \
    --email "$FILEN_EMAIL" \
    --password "$FILEN_PASSWORD"

# API data backup
sudo -E env "PATH=$PATH" filen mkdir /api \
    --email "$FILEN_EMAIL" \
    --password "$FILEN_PASSWORD"
sudo -E env "PATH=$PATH" filen sync $BACKUP_DIR/api:localToCloud:/api \
    --email "$FILEN_EMAIL" \
    --password "$FILEN_PASSWORD"
