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
- Deploy via GitHub Actions + Ansible + rsync
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
- `VPS_SSH_PASSWORD=...`
- `VPS_BECOME_PASSWORD=...`
- `VPS_APP_DIR=/var/www/loja.packetloss.com.br`

## Arquivo `.env.production` na VPS

Use como base: [.env.example](/home/lucas/code/pkl/loja/.env.example)

Criar no servidor:

```bash
sudo mkdir -p /var/www/loja.packetloss.com.br
sudo chown -R nginx:nginx /var/www/loja.packetloss.com.br
sudo -u nginx cp /var/www/loja.packetloss.com.br/.env.production{.example,}
# edite /var/www/loja.packetloss.com.br/.env.production
```

Chaves obrigatórias no `.env.production`:

- `MEDUSA_DATABASE_URL`
- `MEDUSA_JWT_SECRET`
- `MEDUSA_COOKIE_SECRET`
- `MEDUSA_PUBLISHABLE_KEY`

Chaves recomendadas:

- `MEDUSA_REDIS_URL` (default automático: `redis://127.0.0.1:6379`)
- `MEDUSA_STORE_CORS`
- `MEDUSA_ADMIN_CORS`
- `MEDUSA_AUTH_CORS`
- `API_DOMAIN` (default: `api.loja.packetloss.com.br`)
- `NEXT_PUBLIC_DEFAULT_REGION` (default: `br`)

## Scripts de deploy

- [scripts/sync.sh](/home/lucas/code/pkl/loja/scripts/sync.sh): sincroniza arquivos para VPS via rsync/sshpass.
- [scripts/deploy-ansible.sh](/home/lucas/code/pkl/loja/scripts/deploy-ansible.sh): executa playbook Ansible remoto.
- [scripts/deploy.sh](/home/lucas/code/pkl/loja/scripts/deploy.sh): roda sync + deploy completo.

### Uso local dos scripts

```bash
export VPS_HOST=163.176.221.13
export VPS_PORT=2200
export VPS_USER=nginx
export VPS_SSH_PASSWORD='...'
export VPS_BECOME_PASSWORD='...'
export VPS_APP_DIR=/var/www/loja.packetloss.com.br

scripts/deploy.sh
```

## O que o playbook faz

Playbook: [ansible/playbooks/deploy.yml](/home/lucas/code/pkl/loja/ansible/playbooks/deploy.yml)

1. Instala pacotes base (`nginx`, utilitários, SELinux tools).
2. Instala Node.js ARM64 `24.16.0` em `/opt`.
3. Ativa `pnpm@11.3.0` via `corepack`.
4. Instala Redis (`redis`) ou fallback para `valkey`.
5. Garante diretório da app e contexto SELinux.
6. Ativa `httpd_can_network_connect=1` para Nginx falar com Node.
7. Lê `.env.production` da VPS e gera:
   - `apps/backend/.env`
   - `apps/storefront/.env.local`
8. Executa `pnpm install`, `pnpm build` e `medusa db:migrate`.
9. Atualiza serviços systemd:
   - `medusa-backend`
   - `medusa-storefront`
10. Publica configuração Nginx e recarrega.

## GitHub Actions

Workflow: [.github/workflows/deploy.yml](/home/lucas/code/pkl/loja/.github/workflows/deploy.yml)

- Trigger: push na `main` e `workflow_dispatch`
- Usa somente secrets `VPS_*`
- Sincroniza código para VPS
- Executa Ansible remoto para build e restart dos serviços

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
