#!/usr/bin/env bash
set -euo pipefail

TMP_INV="$(mktemp)"
trap 'rm -f "$TMP_INV"' EXIT

cat > "$TMP_INV" <<INVENTORY
[loja_prod]
ananke ansible_host=163.176.221.13 ansible_port=2200 ansible_user=root ansible_python_interpreter=/usr/bin/python3 ansible_shell_executable=/bin/bash ansible_ssh_common_args='-o RequestTTY=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR'
INVENTORY

ANSIBLE_LOCAL_TEMP=./.ansible/tmp ansible-playbook \
  -i "$TMP_INV" \
  ansible/playbooks/deploy.yml \
  -e "app_dir=/var/www/loja.packetloss.com.br" \
  -e "app_user=nginx" \
  -e "app_group=nginx" \
  -e "app_domain=loja.packetloss.com.br" \
  -e "api_domain=api.loja.packetloss.com.br" \
  -e "app_title=Packet Loss Store" \
  -e "default_region=br"
