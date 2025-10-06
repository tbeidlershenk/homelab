for name in $(jq -r '.[] | select(.enabled==true) | .name' "$REGISTRY_PATH"); do
    echo "Starting stack: $name"
    docker compose -f "$SERVICES_DIR/$name.yml" -p "$name" up -d || true
done