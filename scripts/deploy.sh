#!/bin/bash
# Pulls main and re-applies the host state. Triggered by CI via the API.

# The API may restart during this deploy (when its code changed). Re-launch in
# a transient systemd unit so we're not inside the API's cgroup and survive it.
# Logs: journalctl -u 'homelab-deploy-*'
if [ -z "${HOMELAB_DEPLOY_DETACHED:-}" ] && command -v systemd-run >/dev/null; then
    exec systemd-run --unit="homelab-deploy-$(date +%s)" --collect \
        --setenv=HOMELAB_DEPLOY_DETACHED=1 --setenv=HOME=/root /bin/bash "$(readlink -f "${BASH_SOURCE[0]}")"
fi

script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

cd $BASE_DIR
git stash # keep any local edits to tracked files recoverable (git stash list)
git fetch --all
git reset --hard origin/main

$BASE_DIR/scripts/prepare.sh
$BASE_DIR/scripts/restart.sh
