#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/loja.packetloss.com.br}"
PNPM_BIN="${PNPM_BIN:-$HOME/.local/share/pnpm/pnpm}"
NODE_BIN="${NODE_BIN:-$(command -v node)}"

run_sudo() {
  if [[ -n "${VPS_BECOME_PASSWORD:-}" ]]; then
    printf '%s\n' "$VPS_BECOME_PASSWORD" | sudo -S "$@"
  else
    sudo "$@"
  fi
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    tr -dc 'a-f0-9' </dev/urandom | head -c 64
  fi
}

cd "$APP_DIR"

export CI=true

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
: "${MEDUSA_PUBLISHABLE_KEY:?missing MEDUSA_PUBLISHABLE_KEY in .env.production}"

if [[ -z "${MEDUSA_JWT_SECRET:-}" ]]; then
  MEDUSA_JWT_SECRET="$(generate_secret)"
  echo "MEDUSA_JWT_SECRET=$MEDUSA_JWT_SECRET" >> .env.production
  echo "generated MEDUSA_JWT_SECRET in .env.production"
fi

if [[ -z "${MEDUSA_COOKIE_SECRET:-}" ]]; then
  MEDUSA_COOKIE_SECRET="$(generate_secret)"
  echo "MEDUSA_COOKIE_SECRET=$MEDUSA_COOKIE_SECRET" >> .env.production
  echo "generated MEDUSA_COOKIE_SECRET in .env.production"
fi

mkdir -p apps/backend apps/storefront

cat > apps/backend/.env <<EOB
STORE_CORS=${MEDUSA_STORE_CORS:-https://loja.packetloss.com.br}
ADMIN_CORS=${MEDUSA_ADMIN_CORS:-https://loja.packetloss.com.br}
AUTH_CORS=${MEDUSA_AUTH_CORS:-https://loja.packetloss.com.br}
REDIS_URL=${MEDUSA_REDIS_URL:-redis://127.0.0.1:6379}
JWT_SECRET=$MEDUSA_JWT_SECRET
COOKIE_SECRET=$MEDUSA_COOKIE_SECRET
DATABASE_URL=$MEDUSA_DATABASE_URL
MERCADOPAGO_ACCESS_TOKEN=${MERCADOPAGO_ACCESS_TOKEN:-}
MERCADOPAGO_WEBHOOK_SECRET=${MERCADOPAGO_WEBHOOK_SECRET:-}
EOB

cat > apps/storefront/.env.local <<EOS
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$MEDUSA_PUBLISHABLE_KEY
NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://${API_DOMAIN:-api.loja.packetloss.com.br}
NEXT_PUBLIC_DEFAULT_REGION=${NEXT_PUBLIC_DEFAULT_REGION:-br}
NEXT_PUBLIC_BASE_URL=https://loja.packetloss.com.br
NODE_ENV=production
EOS

# Garante contexto SELinux compatível para EnvironmentFile lido pelo systemd.
if command -v /usr/sbin/semanage >/dev/null 2>&1; then
  sudo /usr/sbin/semanage fcontext -a -t etc_t "${APP_DIR}/apps/backend/\\.env" 2>/dev/null \
    || sudo /usr/sbin/semanage fcontext -m -t etc_t "${APP_DIR}/apps/backend/\\.env"
  sudo /usr/sbin/semanage fcontext -a -t etc_t "${APP_DIR}/apps/storefront/\\.env\\.local" 2>/dev/null \
    || sudo /usr/sbin/semanage fcontext -m -t etc_t "${APP_DIR}/apps/storefront/\\.env\\.local"
  sudo /usr/sbin/semanage fcontext -a -t etc_t "${APP_DIR}/apps/storefront-v2/\\.env\\.local" 2>/dev/null \
    || sudo /usr/sbin/semanage fcontext -m -t etc_t "${APP_DIR}/apps/storefront-v2/\\.env\\.local"
  sudo /usr/sbin/semanage fcontext -a -t etc_t "${APP_DIR}/apps/storefront-v2/\\.env\\.production" 2>/dev/null \
    || sudo /usr/sbin/semanage fcontext -m -t etc_t "${APP_DIR}/apps/storefront-v2/\\.env\\.production"
fi
sudo /usr/sbin/restorecon -RF "$APP_DIR" || true

if ! "$PNPM_BIN" install --frozen-lockfile --config.confirmModulesPurge=false; then
  echo "pnpm install falhou por permissão."
  echo "Execute uma vez como root e rode o deploy novamente:"
  echo "  chown -R nginx:nginx $APP_DIR"
  exit 1
fi
"$PNPM_BIN" build
"$PNPM_BIN" --filter @dtc/backend exec medusa db:migrate

if [[ ! -f "$APP_DIR/apps/backend/.medusa/server/public/admin/index.html" ]]; then
  echo "admin build não encontrado em $APP_DIR/apps/backend/.medusa/server/public/admin/index.html"
  echo "falha de build do admin; backend não será reiniciado."
  exit 1
fi

run_sudo /usr/bin/systemctl restart medusa-backend
run_sudo /usr/bin/systemctl restart medusa-storefront
run_sudo /usr/bin/systemctl reload nginx
