#!/usr/bin/env bash
set -euo pipefail

scripts/sync.sh
scripts/deploy-ansible.sh
