# 01 — Propósito e Arquitetura

Aqui você vai entender por que este projeto existe, qual problema ele resolve e como os processos se organizam dentro do container.

---

## O problema

Desenvolver remotamente exige ou um acesso SSH decente (teclado físico, cliente SSH configurado) ou alguma solução de IDE remota. Nenhuma das duas funciona bem num celular. E mesmo no computador, manter uma VPS organizada com múltiplos projetos costuma virar bagunça rapidamente.

## A solução

Um container por projeto. Cada workspace é uma aplicação separada no Coolify, com:

- **Claude Code** operando diretamente no código do projeto (`/workspace`)
- **Bot do Telegram** como interface: você manda a instrução, o bot repassa pro Claude, a resposta volta formatada pra tela do celular
- Opcionalmente, **Claude Remote Control** — sessão interativa acessível via browser em [claude.ai/code](https://claude.ai/code) ou pelo app mobile

O template não muda de projeto para projeto. O que muda são as variáveis de ambiente (token do bot, token do Claude, URL do repositório).

---

## Decisão de arquitetura: um container por projeto

Alternativas consideradas e por que foram descartadas:

- **Um container central com múltiplos projetos**: cria dependências entre projetos, o Claude de um pode "ver" o contexto de outro, e um bug num projeto pode travar o acesso a todos
- **Docker socket exposto**: risco de segurança — qualquer processo dentro do container teria acesso ao daemon Docker da VPS
- **Hub central com roteamento**: complexidade desnecessária, ponto único de falha

Com um container por projeto, cada workspace é isolado: enxerga só o próprio `/workspace`, tem seu próprio bot, e um redeploy de um projeto não afeta os outros.

---

## Arquitetura de processos

```
VPS (Coolify)
└── Container: workspace-meu-projeto
    │
    ├── PID 1: tail -f /dev/null          ← processo guarda; mantém o container vivo
    │
    ├── tmux session: "bot"               ← bot Telegram
    │   └── python /app/bot.py
    │       └── claude --continue -p <instrução>   ← opera em /workspace
    │
    └── tmux session: "claude-rc"         ← Remote Control (opcional)
        └── claude --remote-control [name]
            └── conectado a claude.ai/code via Anthropic
```

### Por que tmux e não processos em background comuns?

- Processos em background (`&`) morrem com o processo pai se o shell fechar
- Sessões tmux são independentes do shell que as criou
- Com tmux é possível anexar (`attach`) e ver o que o Claude está fazendo em tempo real
- Cada serviço pode ser parado/reiniciado individualmente sem derrubar o container

### Fluxo de uma instrução via bot

```
Telegram (celular)
    │
    │  mensagem de texto
    ▼
bot.py (tmux session "bot")
    │
    │  lock por chat — só uma instrução por vez
    │  verifica ALLOWED_USER_IDS
    │  claude --continue -p "<instrução>" \
    │          --append-system-prompt "<prompt Telegram>"
    ▼
claude CLI (subprocess)
    │
    │  opera em /workspace
    │  lê, edita, cria arquivos
    │  pode rodar testes, instalar dependências, etc.
    ▼
resposta em texto
    │
    ▼
Telegram (celular)
```

### Ciclo de vida do container

O `entrypoint.sh` é executado no start e faz, em ordem:

1. Valida variáveis obrigatórias (aborta se faltar alguma)
2. Configura SSH (se `SSH_PRIVATE_KEY` definido)
3. Configura identidade git (se `GIT_USER_NAME`/`GIT_USER_EMAIL` definidos)
4. Autentica GitHub CLI (se `GH_TOKEN` definido)
5. Clona `REPO_URL` em `/workspace` se o diretório estiver vazio
6. Inicia o bot Telegram em tmux (se `ENABLE_BOT` não for false)
7. Inicia o Remote Control em tmux (se `CLAUDE_REMOTE_CONTROL=true`)
8. Entra em modo guarda: `exec tail -f /dev/null` (PID 1)

A partir daí, bot e Remote Control são independentes. O container só cai se explicitamente parado ou se o entrypoint falhar nos passos 1-5.

---

Próximo: [02-deploy-inicial.md](02-deploy-inicial.md) — criar o primeiro workspace no Coolify.
