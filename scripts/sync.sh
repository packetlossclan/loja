#!/usr/bin/env bash
set -euo pipefail

: "${VPS_HOST:?missing VPS_HOST}"
: "${VPS_PORT:?missing VPS_PORT}"
: "${VPS_USER:?missing VPS_USER}"
: "${VPS_APP_DIR:?missing VPS_APP_DIR}"

rsync -az --delete \
  -e "ssh -p $VPS_PORT" \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.next' \
  --exclude '.turbo' \
  --exclude '.env.production' \
  ./ "$VPS_USER@$VPS_HOST:$VPS_APP_DIR/"
