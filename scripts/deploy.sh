#!/usr/bin/env bash
set -euo pipefail

echo "Syncing files to VPS..."
scripts/sync.sh
echo "Running Ansible deploy..."
scripts/deploy-ansible.sh
