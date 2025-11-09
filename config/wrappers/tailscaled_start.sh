#!/usr/bin/env bash
set -e

set -a
source /etc/homelab/.env
set -a

TAILSCALE_STATE_DIR="$BASE_DIR/data/tailscale"
/usr/sbin/tailscaled --statedir=${TAILSCALE_STATE_DIR}