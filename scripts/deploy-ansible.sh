#!/usr/bin/env bash
set -euo pipefail

: "${VPS_HOST:?missing VPS_HOST}"
: "${VPS_PORT:?missing VPS_PORT}"
: "${VPS_USER:?missing VPS_USER}"
: "${VPS_APP_DIR:?missing VPS_APP_DIR}"

ANSIBLE_LOCAL_TEMP=./.ansible/tmp ansible-playbook \
  -i "$VPS_HOST," \
  -u "$VPS_USER" \
  -e "ansible_port=$VPS_PORT" \
  -e "ansible_python_interpreter=/usr/bin/python3" \
  ansible/playbooks/deploy.yml \
  --ask-become-pass \
  -e "app_dir=$VPS_APP_DIR"
