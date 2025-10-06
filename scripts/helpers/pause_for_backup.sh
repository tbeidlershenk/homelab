while IFS= read -r name; do
    echo "Pausing $name..."
    docker compose -f "$SERVICES_DIR/$name.yml" -p "$name" pause || true
done < <(jq -r '.[] | select(.enabled==true and .pause_on_backup==true) | .name' "$REGISTRY_PATH")