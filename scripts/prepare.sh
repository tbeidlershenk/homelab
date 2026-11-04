#!/bin/bash
# Applies the declared host state in ansible/ (idempotent). Re-run by deploy.sh
# on every deploy. Extra arguments go to ansible-playbook, for example:
#   sudo ./scripts/prepare.sh --check --diff        # dry run: what would change
#   sudo ./scripts/prepare.sh --tags api            # (once roles are tagged)
set -eo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)" >&2
    exit 1
fi

script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

repo_root="$(cd "$script_context/.." && pwd)"
export ANSIBLE_CONFIG="$repo_root/ansible/ansible.cfg"
export ENVIRONMENT
exec ansible-playbook "$repo_root/ansible/site.yml" "$@"
