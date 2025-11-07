#!/usr/bin/env bash
set -e

set -a
source /etc/homelab/.env
set -a

cd "$BASE_DIR/homeapi"
exec "$BASE_DIR/homeapi/venv/bin/gunicorn" --workers 3 --bind 0.0.0.0:80 wsgi:server