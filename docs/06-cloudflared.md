# 06 — Cloudflared

Aqui você vai aprender a usar o `cloudflared` para expor apps que rodam dentro do `/workspace` — útil para testar uma API, um frontend ou qualquer serviço HTTP sem precisar mexer em DNS, Coolify ou firewall.

---

## O que é e para que serve

O `cloudflared` cria um tunnel Cloudflare que expõe uma porta local do container para a internet. É útil quando você está desenvolvendo um app no `/workspace` e precisa:

- Acessar a API de fora da VPS (ex: testar webhook do GitHub)
- Mostrar um preview do frontend para alguém
- Conectar um app móvel ao backend em desenvolvimento

O `cloudflared` **não é necessário para o Remote Control** do Claude — o roteamento do Remote Control é feito pela Anthropic. O `cloudflared` serve exclusivamente para expor apps que você mesmo sobe no workspace.

---

## Tunnel rápido (sem conta Cloudflare)

Não precisa de login. Gera uma URL temporária `*.trycloudflare.com`.

### Via setup (recomendado)

```bash
docker exec -it <container> setup
```

Selecione **"Cloudflared: tunnel rápido (--url)"**, informe o número da porta.

### Via linha de comando

```bash
docker exec -it <container> cloudflared tunnel --url http://localhost:8000
```

A URL gerada aparece no output — algo como `https://abc123.trycloudflare.com`. O tunnel fica ativo enquanto o processo estiver rodando. Ctrl-C encerra.

> A URL muda a cada execução e não é fixável sem uma conta Cloudflare.

---

## Tunnel persistente (com conta Cloudflare)

Para um domínio fixo e tunnel com nome:

### 1. Autenticar

```bash
docker exec -it <container> setup
```

Selecione **"Cloudflared: autenticar (login)"**. O setup exibe uma URL — abra no browser, autorize na sua conta Cloudflare. O certificado é salvo em `/root/.cloudflared/`.

### 2. Criar o tunnel

Dentro do container:

```bash
docker exec -it <container> bash
cloudflared tunnel create meu-workspace
```

Isso cria um tunnel com ID fixo e salva as credenciais em `/root/.cloudflared/<ID>.json`.

### 3. Configurar

Crie o arquivo de configuração:

```bash
mkdir -p /root/.cloudflared
cat > /root/.cloudflared/config.yml << 'EOF'
tunnel: <ID-do-tunnel>
credentials-file: /root/.cloudflared/<ID-do-tunnel>.json

ingress:
  - hostname: meu-projeto.meudominio.com
    service: http://localhost:8000
  - service: http_status:404
EOF
```

### 4. Configurar DNS

No painel Cloudflare, crie um registro CNAME:
- Nome: `meu-projeto`
- Conteúdo: `<ID-do-tunnel>.cfargotunnel.com`

### 5. Iniciar o tunnel

```bash
cloudflared tunnel run meu-workspace
```

Para rodar em background, abra em tmux:

```bash
tmux new-session -d -s cloudflared "cloudflared tunnel run meu-workspace"
```

---

## Parar o tunnel

Via setup:

```bash
docker exec -it <container> setup
```

Selecione **"Cloudflared: parar tunnel"**. O setup mata processos `cloudflared tunnel` com `pkill`.

Via linha de comando:

```bash
docker exec -it <container> pkill -f "cloudflared tunnel"
```

---

## Persistência

O certificado (`/root/.cloudflared/cert.pem`) e as credenciais do tunnel ficam em `/root/.cloudflared/`. Esse diretório **não é um volume persistente por padrão**. Se precisar que o tunnel persista entre redeploys, adicione `/root/.cloudflared` como volume no Coolify ou no `docker-compose.yml`.

---

Próximo: [07-casos-de-uso.md](07-casos-de-uso.md) — cenários práticos de uso do workspace.
