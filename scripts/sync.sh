#!/usr/bin/env bash
set -euo pipefail

: "${VPS_HOST:?missing VPS_HOST}"
: "${VPS_PORT:?missing VPS_PORT}"
: "${VPS_USER:?missing VPS_USER}"
: "${VPS_SSH_PASSWORD:?missing VPS_SSH_PASSWORD}"
: "${VPS_APP_DIR:?missing VPS_APP_DIR}"

sshpass -p "$VPS_SSH_PASSWORD" rsync -az --delete \
  -e "ssh -p $VPS_PORT -o StrictHostKeyChecking=no" \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.next' \
  --exclude '.turbo' \
  --exclude '.env.production' \
  ./ "$VPS_USER@$VPS_HOST:$VPS_APP_DIR/"
