#!/usr/bin/env bash
set -e

set -a
source /etc/homelab/.env
set -a



CLOUDFLARED_CONFIG_PATH="$BASE_DIR/data/cloudflared/config.yml"


/usr/local/bin/cloudflared tunnel --config $CLOUDFLARED_CONFIG_PATH run tbeidlershenk.dev-tunnel
