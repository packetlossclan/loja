#!/usr/bin/env bash
set -euo pipefail

: "${VPS_HOST:?missing VPS_HOST}"
: "${VPS_PORT:?missing VPS_PORT}"
: "${VPS_USER:?missing VPS_USER}"
: "${VPS_SSH_PASSWORD:?missing VPS_SSH_PASSWORD}"
: "${VPS_BECOME_PASSWORD:?missing VPS_BECOME_PASSWORD}"
: "${VPS_APP_DIR:?missing VPS_APP_DIR}"

TMP_INV="$(mktemp)"
trap 'rm -f "$TMP_INV"' EXIT

cat > "$TMP_INV" <<INVENTORY
[loja_prod]
$VPS_HOST ansible_port=$VPS_PORT ansible_user=$VPS_USER ansible_ssh_pass='$VPS_SSH_PASSWORD' ansible_become_pass='$VPS_BECOME_PASSWORD'

[all:vars]
ansible_connection=ssh
ansible_python_interpreter=/usr/bin/python3
INVENTORY

ansible-galaxy collection install community.general
ANSIBLE_LOCAL_TEMP=./.ansible/tmp ansible-playbook \
  -i "$TMP_INV" \
  ansible/playbooks/deploy.yml \
  -e app_dir="$VPS_APP_DIR" \
  -e app_user="nginx" \
  -e app_group="nginx" \
  -e app_domain="loja.packetloss.com.br" \
  -e api_domain="api.loja.packetloss.com.br" \
  -e app_title="Packet Loss Store" \
  -e default_region="br"
