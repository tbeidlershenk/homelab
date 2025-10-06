for name in $(jq -r '.[] | select(.enabled==false)| .name' "$REGISTRY_PATH"); do
    echo "Stopping stack: $name"
    docker compose -f "$SERVICES_DIR/$name.yml" -p "$name" down --remove-orphans || true
done