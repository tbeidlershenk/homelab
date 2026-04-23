#!/usr/bin/env bash
set -e

set -a
source /etc/homelab/.env
set -a

cd "$BASE_DIR/homeapi"
exec "$BASE_DIR/homeapi/venv/bin/gunicorn" \
    -k gevent \
    --workers 3 \
    --bind 0.0.0.0:5001 \
    --timeout 0 \
    --keep-alive 60 \
    wsgi:server