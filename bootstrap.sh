#!/bin/bash
# Fresh machine → fully configured homelab host.
#   git clone https://github.com/tbeidlershenk/homelab.git && cd homelab
#   (place the Doppler bootstrap .env: DOPPLER_PROJECT / DOPPLER_CONFIG / DOPPLER_TOKEN)
#   sudo ./bootstrap.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
./scripts/install.sh
./scripts/prepare.sh "$@"
