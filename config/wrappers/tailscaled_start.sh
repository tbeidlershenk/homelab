#!/usr/bin/env bash
set -e

set -a
source /etc/homelab/.env
set -a

cd /var/lib/tailscale
/usr/sbin/tailscaled --statedir=${TAILSCALE_STATE_DIR}