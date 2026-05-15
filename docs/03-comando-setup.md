# 03 — Comando `setup`

Aqui você vai aprender o que cada opção do menu `setup` faz e quando usar cada uma.

O `setup` é um menu interativo para ajustes pontuais depois do deploy — sem precisar redesenhar variáveis de ambiente ou fazer redeploy.

---

## Como acessar

```bash
ssh usuario@ip-da-vps
docker exec -it <nome-do-container> setup
```

O menu aparece numerado. Digite o número da opção e tecle Enter.

---

## Opções do menu

### 1. Clonar / trocar repositório

**Quando usar:** no primeiro start (se não definiu `REPO_URL`) ou quando quiser trocar o projeto do workspace por outro.

**O que faz:** pergunta a URL do repositório, confirma, limpa todo o `/workspace` e executa `git clone`.

> Cuidado: isso apaga tudo em `/workspace`. Trabalho não commitado é perdido.

---

### 2. Autenticar GitHub CLI (colar token)

**Quando usar:** quando precisar operar em repositórios privados do GitHub via HTTPS (push, pull, clone) e não definiu `GH_TOKEN` no Coolify.

**O que faz:** lê um Personal Access Token do GitHub (entrada oculta), executa `gh auth login --with-token` e `gh auth setup-git` para que o `git` use o token em operações HTTPS.

**Alternativa via env:** defina `GH_TOKEN` no Coolify. O entrypoint configura automaticamente no boot.

---

### 3. Clonar repositórios (GitHub CLI)

**Quando usar:** quando o GitHub CLI já está autenticado e você quer clonar um ou mais repos seus em `/workspace/<nome>` (útil para workspaces multi-repo).

**O que faz:** busca a lista dos seus repositórios via `gh repo list`, exibe numerada, você digita os números desejados separados por espaço e ele clona cada um.

**Pré-requisito:** `gh` autenticado (opção 2 ou `GH_TOKEN` definido).

---

### 4. Configurar chave SSH (colar)

**Quando usar:** quando precisar clonar/fazer push em repos privados via SSH (GitHub, GitLab ou outro host Git) e não definiu `SSH_PRIVATE_KEY` no Coolify.

**O que faz:** pede que você cole a chave privada (finalize com Ctrl-D), salva em `/root/.ssh/id_ed25519` com permissão 600 e adiciona `github.com` e `gitlab.com` ao `known_hosts`.

---

### 5. Configurar identidade git

**Quando usar:** quando os commits saem sem nome/email (erro "Please tell me who you are") e você não definiu `GIT_USER_NAME`/`GIT_USER_EMAIL` no Coolify.

**O que faz:** pede nome e email, executa `git config --global user.name` e `git config --global user.email`.

---

### 6. Testar Claude Code

**Quando usar:** para verificar se o `CLAUDE_CODE_OAUTH_TOKEN` está válido e o `claude` CLI está funcionando.

**O que faz:** executa `claude -p "responda apenas: ok"`. Se retornar "ok", está tudo certo. Se falhar, verifique o token.

---

### 7. Autenticar Claude (full-scope, necessário para Remote Control)

**Quando usar:** quando quiser usar o Remote Control ([05-remote-control.md](05-remote-control.md)). O `CLAUDE_CODE_OAUTH_TOKEN` padrão é inference-only e não habilita essa feature.

**Como funciona:**

1. O menu exibe uma explicação e pede confirmação
2. Executa `claude auth login`
3. O Claude exibe uma URL no terminal — copie e abra no navegador (do PC ou celular)
4. Autorize na sua conta Anthropic
5. As credenciais são salvas em `/root/.claude/` — volume persistente, sobrevive a redeploys

Depois do login, reinicie o Remote Control (opção 12) para que a sessão tmux use as novas credenciais.

> Este fluxo é feito **uma vez por workspace**. As credenciais ficam no volume `/root/.claude` e não precisam ser refeitas a cada redeploy.

---

### 8. Bot: iniciar

**Quando usar:** quando o bot está parado e você quer subir sem fazer redeploy.

**O que faz:** chama `bot-control start`, que cria uma sessão tmux chamada `bot` rodando `python /app/bot.py`.

---

### 9. Bot: parar

**Quando usar:** para desligar o bot temporariamente (manutenção, debugging).

**O que faz:** chama `bot-control stop`, que mata a sessão tmux `bot`.

---

### 10. Bot: reiniciar

**Quando usar:** o bot travou, começou a se comportar de forma estranha ou você mudou alguma configuração.

**O que faz:** para e reinicia a sessão tmux do bot.

---

### 11. Bot: ver logs (tail)

**Quando usar:** para acompanhar o que o bot está fazendo em tempo real ou investigar erros.

**O que faz:** faz `tail -n 100 -f /var/log/bot.log`. Ctrl-C para sair (não mata o bot, só o tail).

---

### 12. Reiniciar Claude Remote Control

**Quando usar:** após fazer o login full-scope (opção 7), ou quando a sessão do Remote Control travar/sumir.

**O que faz:** chama `remote-control restart`, que mata a sessão tmux `claude-rc` e cria uma nova com `claude --remote-control`.

> Se `CLAUDE_REMOTE_CONTROL=false`, a sessão pode não ter subido no boot — use esta opção para iniciar manualmente.

---

### 13. Cloudflared: autenticar (login)

**Quando usar:** antes de criar tunnels persistentes (com nome e domínio fixo). Não necessário para tunnels rápidos (`trycloudflare`).

**O que faz:** executa `cloudflared tunnel login`, que exibe uma URL para autorizar na sua conta Cloudflare. Salva o certificado em `/root/.cloudflared/`.

---

### 14. Cloudflared: tunnel rápido (--url)

**Quando usar:** para expor uma porta local do workspace rapidamente, sem conta Cloudflare.

**O que faz:** pede o número da porta e executa `cloudflared tunnel --url http://localhost:<porta>`. Exibe uma URL `*.trycloudflare.com` temporária. Ctrl-C encerra o tunnel.

Veja mais em [06-cloudflared.md](06-cloudflared.md).

---

### 15. Cloudflared: parar tunnel

**Quando usar:** para encerrar um tunnel `cloudflared` que esteja rodando em background.

**O que faz:** mata processos `cloudflared tunnel` com `pkill`.

---

### 16. Ver status

**Quando usar:** para ter uma visão rápida do estado do workspace.

**O que faz:** exibe:
- Status git do `/workspace` (`git status`)
- Status do bot Telegram (`bot-control status`)
- Status do Remote Control (`remote-control status`)
- Se o cloudflared está rodando

---

### 17. Sair

Encerra o menu `setup`. O container continua rodando normalmente.

---

Próximo: [04-bot-telegram.md](04-bot-telegram.md) — como usar o bot no dia a dia.
