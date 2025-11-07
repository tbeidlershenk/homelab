# Helper to restore volumes from Filen cloud backup

for name in $(jq -r '.[] | select(.cloud_backup==true) | .name' "$REGISTRY_PATH"); do
    echo "Restoring $name from Filen..."
    sudo filen -E env "PATH=$PATH" sync /$name:cloudToLocal:$DATA_DIR/$name \
        --email "$FILEN_EMAIL" \
        --password "$FILEN_PASSWORD"
done