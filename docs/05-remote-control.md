# 05 — Claude Remote Control

Aqui você vai aprender a configurar e usar o Remote Control: uma sessão interativa do Claude Code acessível via [claude.ai/code](https://claude.ai/code) ou pelo app mobile, sem precisar de SSH.

---

## O que é o Remote Control

O Remote Control é uma feature do Claude Code (`claude --remote-control`) que conecta a sessão local a um backend da Anthropic. Você acessa essa sessão remotamente pelo browser em claude.ai/code — é como "parear" com o Claude que está rodando dentro do container.

É diferente do bot Telegram:
- **Bot Telegram:** instrução por mensagem, sem interatividade, formatado para celular
- **Remote Control:** sessão interativa completa, com a interface do Claude Code, em tempo real

---

## Pré-requisito crítico: login full-scope

O `CLAUDE_CODE_OAUTH_TOKEN` definido no Coolify é um token **inference-only** — funciona para `claude -p` (usado pelo bot Telegram) mas a Anthropic restringe o Remote Control a tokens obtidos via OAuth interativo com escopo completo.

Sem o login full-scope, o `claude --remote-control` pode até iniciar, mas:
- Não aparece na lista do claude.ai/code
- Se você executar `/remote-control` dentro da sessão tmux, aparece: "Remote Control requires a full-scope login token"

---

## Fluxo completo de configuração

### 1. Habilitar no boot (opcional, mas conveniente)

No Coolify, defina a variável de ambiente:

```
CLAUDE_REMOTE_CONTROL=true
```

Opcionalmente, defina um nome para identificar a sessão no claude.ai/code:

```
CLAUDE_REMOTE_CONTROL_NAME=meu-projeto-api
```

Se não definir o nome, a sessão aparece com um identificador padrão.

### 2. Fazer o deploy

Com `CLAUDE_REMOTE_CONTROL=true`, o entrypoint vai tentar subir a sessão no boot. Ela pode iniciar, mas **não vai aparecer** no claude.ai/code até o login full-scope ser feito.

### 3. Fazer o login full-scope

```bash
docker exec -it <nome-do-container> setup
```

Selecione a opção **"Autenticar Claude (full-scope, necessário para Remote Control)"**.

O que acontece:
1. O menu exibe uma explicação e pede confirmação (`s/N`)
2. Executa `claude auth login`
3. O Claude exibe uma URL no terminal — copie e abra no navegador
4. Faça login na sua conta Anthropic e autorize o acesso
5. O Claude grava as credenciais em `/root/.claude/` (volume persistente)

> **Uma vez só por workspace.** As credenciais ficam no volume `/root/.claude` e sobrevivem a redeploys enquanto o volume existir.

### 4. Reiniciar a sessão Remote Control

Após o login, a sessão tmux existente ainda usa as credenciais antigas (ou nenhuma). Reinicie:

```bash
docker exec -it <container> setup
```

Selecione **"Reiniciar Claude Remote Control"**.

Ou diretamente:

```bash
docker exec -it <container> remote-control restart
```

### 5. Acessar via claude.ai/code

Abra [claude.ai/code](https://claude.ai/code) no browser. O workspace deve aparecer na lista de sessões disponíveis. Clique para conectar.

---

## Detalhe importante: token inference-only é removido

Quando o `remote-control.sh` inicia o Claude, ele faz `unset CLAUDE_CODE_OAUTH_TOKEN` e `unset ANTHROPIC_API_KEY` antes de executar `claude --remote-control`. Isso é intencional.

Se o token inference-only estiver presente no ambiente, o Claude o usa e ignora as credenciais full-scope em `/root/.claude/.credentials.json`. Removendo os tokens do ambiente, o Claude usa apenas as credenciais do volume, que têm o escopo correto.

---

## Gerenciar a sessão Remote Control

A sessão roda em tmux com o nome `claude-rc`. Comandos disponíveis dentro do container:

```bash
remote-control status    # verifica se a sessão está ativa
remote-control start     # inicia (se não estiver rodando)
remote-control stop      # encerra a sessão
remote-control restart   # para e reinicia
remote-control attach    # abre a sessão interativamente (Ctrl-b d para sair sem matar)
```

Para ver o que está acontecendo na sessão sem interagir:

```bash
docker exec -it <container> tmux attach -t claude-rc
# Ctrl-b d para desanexar sem encerrar
```

---

## `prime-claude-config.sh` — evitar travamentos no boot

Ao iniciar `claude --remote-control` em tmux (sem terminal interativo), o Claude pode travar esperando o usuário:
- Escolher o tema (dark/light)
- Confirmar o wizard de boas-vindas
- Aceitar o diálogo de trust do projeto

O script `prime-claude-config.sh` resolve isso: ele patcha `/root/.claude.json` marcando todos esses flags como já aceitos antes de iniciar a sessão. É executado automaticamente pelo `entrypoint.sh` e pelo `remote-control.sh` antes de cada start.

Os flags que ele define:
- `hasCompletedOnboarding: true`
- `hasSeenWelcome: true`
- `onboardingShown: true`
- `hasTrustDialogAccepted: true` (por projeto/WORK_DIR)

---

## Cloudflared não é necessário para Remote Control

O roteamento entre o container e o claude.ai/code é feito pela própria infraestrutura da Anthropic. Não é necessário expor nenhuma porta nem configurar tunnels. O `cloudflared` no container serve para outro propósito — veja [06-cloudflared.md](06-cloudflared.md).

---

## Cenário de uso típico

Você está no celular e quer uma sessão mais rica do que o bot Telegram oferece:

1. Abra o app do Claude (ou browser em claude.ai/code)
2. Acesse a seção de sessões remotas
3. Selecione o workspace
4. Você tem acesso a uma sessão Claude Code completa, operando no `/workspace` da VPS

---

Próximo: [06-cloudflared.md](06-cloudflared.md) — expor portas locais do workspace via Cloudflare Tunnel.
