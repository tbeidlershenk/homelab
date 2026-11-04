#!/usr/bin/env bash
# Acts as a wrapper to inject secrets directly into the environment

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
if [ -f $ENV_FILE ]; then
    set -a; source $ENV_FILE; set +a
fi

# Check for Doppler variables
[ -z "$DOPPLER_PROJECT" ] && echo "Error: DOPPLER_PROJECT is not configured." && exit 1
[ -z "$DOPPLER_CONFIG" ] && echo "Error: DOPPLER_CONFIG is not configured." && exit 1
[ -z "$DOPPLER_TOKEN" ] && echo "Error: DOPPLER_TOKEN is not configured." && exit 1

# Save to .env file for systemd services
echo "Environment: $DOPPLER_CONFIG"
echo "Downloading secrets from PROJECT: $DOPPLER_PROJECT, CONFIG: $DOPPLER_CONFIG..."
mkdir -p /etc/homelab
ENV_OUT=/etc/homelab/.env

# Write to a root-only temp file, then atomically replace the old file, so
# secrets are never world-readable and services never see a half-written file.
tmp="$(mktemp /etc/homelab/.env.XXXXXX)"   # mktemp creates it 0600
trap 'rm -f "$tmp"' EXIT

# JSON + shlex.quote: values are single-quoted, so sourcing the file
# (as the systemd wrappers do) can never execute anything inside a secret.
doppler secrets download \
    --token "$DOPPLER_TOKEN" \
    --project "$DOPPLER_PROJECT" \
    --config "$DOPPLER_CONFIG" \
    --no-file \
    --format json \
| python3 -c '
import json, re, shlex, sys
for k, v in json.load(sys.stdin).items():
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k):
        print(f"{k}={shlex.quote(str(v))}")
' > "$tmp" || { echo "Error: failed to download secrets from Doppler." >&2; exit 1; }

chmod 600 "$tmp"
mv -f "$tmp" "$ENV_OUT"
trap - EXIT
echo "Saved secrets to $ENV_OUT (mode 600)."