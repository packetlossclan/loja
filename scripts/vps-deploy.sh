#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/loja.packetloss.com.br}"
PNPM_BIN="${PNPM_BIN:-$HOME/.local/share/pnpm/pnpm}"

run_sudo() {
  if [[ -n "${VPS_BECOME_PASSWORD:-}" ]]; then
    printf '%s\n' "$VPS_BECOME_PASSWORD" | sudo -S "$@"
  else
    sudo "$@"
  fi
}

cd "$APP_DIR"

if [[ ! -f .env.production ]]; then
  echo "missing $APP_DIR/.env.production"
  exit 1
fi

if [[ ! -x "$PNPM_BIN" ]]; then
  echo "pnpm not found at: $PNPM_BIN"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source ./.env.production
set +a

: "${MEDUSA_DATABASE_URL:?missing MEDUSA_DATABASE_URL in .env.production}"
: "${MEDUSA_JWT_SECRET:?missing MEDUSA_JWT_SECRET in .env.production}"
: "${MEDUSA_COOKIE_SECRET:?missing MEDUSA_COOKIE_SECRET in .env.production}"
: "${MEDUSA_PUBLISHABLE_KEY:?missing MEDUSA_PUBLISHABLE_KEY in .env.production}"

mkdir -p apps/backend apps/storefront

cat > apps/backend/.env <<EOB
STORE_CORS=${MEDUSA_STORE_CORS:-https://loja.packetloss.com.br}
ADMIN_CORS=${MEDUSA_ADMIN_CORS:-https://loja.packetloss.com.br}
AUTH_CORS=${MEDUSA_AUTH_CORS:-https://loja.packetloss.com.br}
REDIS_URL=${MEDUSA_REDIS_URL:-redis://127.0.0.1:6379}
JWT_SECRET=$MEDUSA_JWT_SECRET
COOKIE_SECRET=$MEDUSA_COOKIE_SECRET
DATABASE_URL=$MEDUSA_DATABASE_URL
EOB

cat > apps/storefront/.env.local <<EOS
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$MEDUSA_PUBLISHABLE_KEY
NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://${API_DOMAIN:-api.loja.packetloss.com.br}
NEXT_PUBLIC_DEFAULT_REGION=${NEXT_PUBLIC_DEFAULT_REGION:-br}
NEXT_PUBLIC_BASE_URL=https://loja.packetloss.com.br
NODE_ENV=production
EOS

"$PNPM_BIN" install --frozen-lockfile
"$PNPM_BIN" build
"$PNPM_BIN" --filter @dtc/backend exec medusa db:migrate

run_sudo systemctl restart medusa-backend
run_sudo systemctl restart medusa-storefront
run_sudo systemctl reload nginx
