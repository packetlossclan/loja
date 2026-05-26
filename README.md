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
5. Valida que o admin build existe em `apps/backend/.medusa/server/public/admin/index.html`.
6. Reinicia `medusa-backend` e `medusa-storefront`, e recarrega `nginx`.

## GitHub Actions

Workflow: [.github/workflows/deploy.yml](/home/lucas/code/pkl/loja/.github/workflows/deploy.yml)

- Trigger: push na `main` e `workflow_dispatch`
- Usa somente secrets `VPS_*`
- Sincroniza código para VPS
- Executa `scripts/vps-deploy.sh` na VPS para build, migration e restart dos serviços
- As units systemd são gerenciadas pelo Ansible (não pelo script remoto).

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

Para (re)criar/atualizar as units systemd via Ansible:

```bash
scripts/deploy-ansible.sh
```

## Acesso ao Admin (senha)

Se você acessou `https://api.loja.packetloss.com.br/app` e não tem senha do admin, crie/reset via CLI:

```bash
cd /var/www/loja.packetloss.com.br/apps/backend
/home/nginx/.local/share/pnpm/pnpm exec medusa user -e admin@packetloss.com.br -p 'SENHA_FORTE_AQUI'
```

Se sua versão não aceitar `-p`, rode:

```bash
cd /var/www/loja.packetloss.com.br/apps/backend
/home/nginx/.local/share/pnpm/pnpm exec medusa user -e admin@packetloss.com.br
```

e siga o prompt para definir a senha.

## O que fazer após primeiro login no painel

1. Criar/confirmar `Region` (Brasil) e moeda (`BRL`).
2. Revisar `Store Settings` (nome, e-mails, endereço fiscal).
3. Criar `Shipping Profile` e opções de frete.
4. Cadastrar produtos, variantes, estoque e categorias.
5. Gerar/confirmar `Publishable API Key` usada no storefront (`MEDUSA_PUBLISHABLE_KEY`).
6. Configurar provedor de pagamento (ex.: Stripe/Mercado Pago) antes de abrir checkout.
7. Validar fluxo ponta a ponta no storefront:
   - listagem de produtos
   - carrinho
   - checkout
   - criação de pedido

## Mercado Pago (PIX e Boleto)

Implementação adicionada no backend com provider:
- pacote: `@nicogorga/medusa-payment-mercadopago`
- ativação condicional: só é habilitado se `MERCADOPAGO_ACCESS_TOKEN` existir no ambiente

### 1) Configurar variáveis na VPS

Edite:

```bash
vim /var/www/loja.packetloss.com.br/.env.production
```

Adicione:

```env
MERCADOPAGO_ACCESS_TOKEN=APP_USR-...
MERCADOPAGO_WEBHOOK_SECRET=...
```

### 2) Configurar webhook no Mercado Pago

No painel de desenvolvedor do Mercado Pago, configure webhook de pagamentos para:

```text
https://api.loja.packetloss.com.br/hooks/payment/mercadopago_mercadopago
```

### 3) Aplicar deploy

```bash
cd /var/www/loja.packetloss.com.br
bash scripts/vps-deploy.sh
./scripts/deploy-ansible.sh
```

### 4) Habilitar provider na Region

No Admin (`https://api.loja.packetloss.com.br/app`):
1. Vá em `Settings -> Regions`
2. Abra a região Brasil
3. Em `Payment Providers`, habilite Mercado Pago

### 5) Observações importantes

- O plugin usado é marcado como WIP pelo mantenedor.
- Faça teste completo com credenciais de teste antes de produção.

### Aplicar a Publishable Key no storefront

1. Edite na VPS:

```bash
vim /var/www/loja.packetloss.com.br/.env.production
```

2. Ajuste:

```env
MEDUSA_PUBLISHABLE_KEY=pk_...
```

3. Reaplique o deploy remoto:

```bash
cd /var/www/loja.packetloss.com.br
bash scripts/vps-deploy.sh
```

4. Verifique se foi propagado para o storefront:

```bash
cat /var/www/loja.packetloss.com.br/apps/storefront/.env.local
```

Deve conter:

```env
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_...
```

Se aparecer erro de permissão no `pnpm install` (arquivos legados com owner `root`), corrija uma única vez:

```bash
sudo chown -R nginx:nginx /var/www/loja.packetloss.com.br
```

Se o `journalctl` mostrar:

- `Failed to load environment files: Permission denied`
- `Failed to spawn 'start' task: Permission denied`

execute:

```bash
sudo restorecon -RFv /var/www/loja.packetloss.com.br
sudo restorecon -v /home/nginx/.local/share/pnpm/pnpm
sudo systemctl daemon-reload
sudo systemctl restart medusa-backend
sudo systemctl status medusa-backend -l
```

No deploy automático, o script [scripts/vps-deploy.sh](/home/lucas/code/pkl/loja/scripts/vps-deploy.sh) já roda:

```bash
sudo restorecon -RF "$APP_DIR"
```

Além disso, ele fixa o contexto SELinux dos arquivos de ambiente para uso com `EnvironmentFile` do systemd:

- `apps/backend/.env` -> `etc_t`
- `apps/storefront/.env.local` -> `etc_t`

## Guia PostgreSQL (Oracle Linux)

Se o deploy falhar por credenciais/DB, use este fluxo.

### 1) Conectar no PostgreSQL

No servidor:

```bash
sudo -u postgres psql
```

Se precisar conectar por host/porta explícitos:

```bash
psql -h 127.0.0.1 -p 5432 -U postgres
```

### 2) Criar usuário (role) e banco para a loja

No `psql`:

```sql
CREATE ROLE loja_user WITH LOGIN PASSWORD 'troque-esta-senha-forte';
CREATE DATABASE loja_db OWNER loja_user;
GRANT ALL PRIVILEGES ON DATABASE loja_db TO loja_user;
```

### 3) Garantir permissões no schema `public`

Conecte no banco:

```sql
\c loja_db
GRANT ALL ON SCHEMA public TO loja_user;
ALTER SCHEMA public OWNER TO loja_user;
```

### 4) Configurar a URL no `.env.production`

Em `/var/www/loja.packetloss.com.br/.env.production`:

```env
MEDUSA_DATABASE_URL=postgres://loja_user:troque-esta-senha-forte@127.0.0.1:5432/loja_db
```

Se a senha tiver caracteres especiais, faça URL encode.

### 5) Testar credenciais rapidamente

No servidor:

```bash
psql "postgres://loja_user:troque-esta-senha-forte@127.0.0.1:5432/loja_db" -c "select current_user, current_database();"
```

### 6) Alterar senha de usuário

No `psql`:

```sql
ALTER ROLE loja_user WITH PASSWORD 'nova-senha-forte';
```

Depois, atualize `MEDUSA_DATABASE_URL` e rode novo deploy.

### 7) Excluir banco e usuário (com cuidado)

No `psql`:

```sql
-- encerra conexões ativas no banco
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'loja_db' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS loja_db;
DROP ROLE IF EXISTS loja_user;
```

### 8) Comandos úteis de inspeção

No `psql`:

```sql
\l               -- lista bancos
\du              -- lista usuários/roles
\c loja_db       -- conecta no banco
\dt              -- lista tabelas
```

### 9) Erro comum no prompt do psql

Se aparecer erro como:

```text
ERROR:  syntax error at or near "psql"
```

você provavelmente executou um comando de shell dentro do prompt SQL.

- `postgres=#` ou `postgres-#`: aceita **SQL** e meta-comandos `\...`
- shell Linux (`#`/`$`): aceita comandos como `psql ...`

No `psql`, rode somente SQL:

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'packetloss_store'
  AND pid <> pg_backend_pid();
```

Se o prompt estiver preso em `postgres-#`, cancele com `Ctrl+C` ou `\reset`.

Para rodar comando de shell sem sair do `psql`, use:

```sql
\! psql --version
```
