# Packet Loss Store (`loja`)

Monorepo MedusaJS + Next.js.

- Frontend: `https://loja.packetloss.com.br`
- Backend API: `https://api.loja.packetloss.com.br`
- VPS: `163.176.221.13:2200`
- User: `nginx`
- App dir: `/var/www/loja.packetloss.com.br`

## Stack

- Node.js `v24.16.0`
- pnpm `11.3.0`
- Medusa backend em `apps/backend`
- Storefront Next.js em `apps/storefront`
- Deploy via GitHub Actions + rsync + shell remoto
- Produção: Oracle Linux 10 ARM64 com SELinux ativo

## Estratégia de configuração

No GitHub Secrets serão usadas **somente variáveis `VPS_*`**.

As variáveis da aplicação (DB, JWT, publishable key, CORS, etc.) ficam em um arquivo na VPS:

- `/var/www/loja.packetloss.com.br/.env.production`

Esse arquivo **não é sobrescrito** pelo sync (`rsync` exclui `.env.production`).

## GitHub Secrets (somente VPS_)

- `VPS_HOST=163.176.221.13`
- `VPS_PORT=2200`
- `VPS_USER=nginx`
- `VPS_SSH_PASSWORD=...` (apenas para GitHub Actions)
- `VPS_BECOME_PASSWORD=...` (apenas para GitHub Actions)
- `VPS_APP_DIR=/var/www/loja.packetloss.com.br`

## Arquivo `.env.production` na VPS

Use como base: [.env.production.example](/home/lucas/code/pkl/loja/.env.production.example)

Criar no servidor:

```bash
sudo mkdir -p /var/www/loja.packetloss.com.br
sudo chown -R nginx:nginx /var/www/loja.packetloss.com.br
sudo -u nginx cp /var/www/loja.packetloss.com.br/.env.production{.example,}
# edite /var/www/loja.packetloss.com.br/.env.production
```

Chaves obrigatórias no `.env.production`:

- `MEDUSA_DATABASE_URL`
- `MEDUSA_PUBLISHABLE_KEY`

`MEDUSA_JWT_SECRET` e `MEDUSA_COOKIE_SECRET`:
- se ausentes no primeiro deploy, o script remoto gera automaticamente e salva no `.env.production`.
- você também pode definir manualmente antes do deploy.

Geração manual recomendada:

```bash
openssl rand -hex 32
```

Chaves recomendadas:

- `MEDUSA_REDIS_URL` (default automático: `redis://127.0.0.1:6379`)
- `MEDUSA_STORE_CORS`
- `MEDUSA_ADMIN_CORS`
- `MEDUSA_AUTH_CORS`
- `API_DOMAIN` (default: `api.loja.packetloss.com.br`)
- `NEXT_PUBLIC_DEFAULT_REGION` (default: `br`)

## Scripts de deploy

- [scripts/sync.sh](/home/lucas/code/pkl/loja/scripts/sync.sh): sincroniza arquivos para VPS via rsync (SSH por chave/config local).
- [scripts/deploy.sh](/home/lucas/code/pkl/loja/scripts/deploy.sh): roda sync + deploy completo.

### Uso local dos scripts

```bash
export VPS_HOST=163.176.221.13
export VPS_PORT=2200
export VPS_USER=nginx
export VPS_APP_DIR=/var/www/loja.packetloss.com.br

scripts/deploy.sh
```

Obs.: no deploy local (`scripts/deploy.sh`), o Ansible pedirá senha de sudo interativamente.

## O que o script remoto faz

Script: [scripts/vps-deploy.sh](/home/lucas/code/pkl/loja/scripts/vps-deploy.sh)

1. Lê `.env.production` na VPS e valida chaves obrigatórias.
2. Gera `apps/backend/.env` e `apps/storefront/.env.local`.
3. Usa pnpm do usuário `nginx` em `/home/nginx/.local/share/pnpm/pnpm`.
4. Executa `pnpm install`, `pnpm build` e `medusa db:migrate`.
5. Reinicia `medusa-backend` e `medusa-storefront`, e recarrega `nginx`.

## GitHub Actions

Workflow: [.github/workflows/deploy.yml](/home/lucas/code/pkl/loja/.github/workflows/deploy.yml)

- Trigger: push na `main` e `workflow_dispatch`
- Usa somente secrets `VPS_*`
- Sincroniza código para VPS
- Executa `scripts/vps-deploy.sh` na VPS para build, migration e restart dos serviços

## TLS/Nginx

Template Nginx: [ansible/templates/nginx-loja.conf.j2](/home/lucas/code/pkl/loja/ansible/templates/nginx-loja.conf.j2)

Certificado esperado por padrão:

- `/etc/letsencrypt/live/loja.packetloss.com.br/fullchain.pem`
- `/etc/letsencrypt/live/loja.packetloss.com.br/privkey.pem`

## Primeiro deploy (resumo)

1. Criar `.env.production` na VPS.
2. Configurar secrets `VPS_*` no GitHub.
3. Fazer push para `main`.
4. Validar serviços:

```bash
sudo systemctl status medusa-backend
sudo systemctl status medusa-storefront
sudo systemctl status nginx
```

Se aparecer erro de permissão no `pnpm install` (arquivos legados com owner `root`), corrija uma única vez:

```bash
sudo chown -R nginx:nginx /var/www/loja.packetloss.com.br
```
