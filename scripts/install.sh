#!/bin/bash
# Installs the two prerequisites the Ansible playbook needs: Ansible itself and
# the Doppler CLI (which supplies its settings). Everything else is declared in
# ansible/ and applied by scripts/prepare.sh.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ansible-core python3-debian curl ca-certificates git gnupg python3

# Doppler's signed apt repo (replaces piping cli.doppler.com/install.sh to sh).
# Skipped if a doppler binary already exists, e.g. from the old installer.
if ! command -v doppler >/dev/null; then
    curl -fsSL --retry 3 --proto '=https' \
        https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key \
        | gpg --dearmor --yes -o /usr/share/keyrings/doppler-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" \
        > /etc/apt/sources.list.d/doppler-cli.list
    apt-get update
    apt-get install -y doppler
fi

ansible --version | head -1
doppler --version
echo "Prerequisites installed. Next: sudo ./scripts/prepare.sh"
