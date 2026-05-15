# 01 — Propósito e Arquitetura

Aqui você vai entender por que este projeto existe, qual problema ele resolve e como os processos se organizam dentro do container.

---

## O problema

Vibecode com agentes de IA (Claude Code, principalmente) é poderoso, mas perigoso quando feito sem barreira: o agente pode rodar comandos, instalar pacotes, mexer em arquivos e tocar em qualquer coisa que estiver acessível no sistema. Rodar isso na sua máquina pessoal mistura tudo num único contexto; rodar direto numa VPS sem isolamento expõe outros projetos e o próprio host.

E em paralelo: você quer desenvolver de qualquer lugar (inclusive do celular) sem precisar de cliente SSH, teclado físico, ou VS Code remoto.

## A solução

Um **sandbox por projeto** — container Docker isolado, com superfície de ataque mínima:

- **Sem Docker socket exposto** — o agente dentro do container não consegue criar/manipular outros containers
- **Sem visibilidade entre projetos** — cada workspace só enxerga o próprio `/workspace`; o Claude de um projeto nunca vê código ou contexto de outro
- **Network restrita pelo Coolify** — cada container fica numa rede gerenciada, sem acesso lateral a outros serviços do host
- **Volumes nomeados separados** — `/workspace` e `/root/.claude` (credenciais OAuth) são isolados por workspace

Dentro do sandbox seguro, o Claude Code opera com liberdade no código do projeto. Você manda instruções de duas formas, conforme o cenário:

- **Bot do Telegram** — pra demandas rápidas direto do celular (mensagem → Claude processa → resposta formatada)
- **Claude Remote Control** — sessão interativa acessível via [claude.ai/code](https://claude.ai/code) ou app mobile, ideal pra trabalho longo de vibecode

O template não muda de projeto para projeto. O que muda são as variáveis de ambiente (token do bot, token do Claude, URL do repositório) e os volumes.

---

## Decisão de arquitetura: um container por projeto

Alternativas consideradas e por que foram descartadas:

- **Um container central com múltiplos projetos**: quebra o isolamento — o Claude de um projeto teria contexto/acesso a outros, e um bug em qualquer um trava o acesso a todos. Inviável para vibecode seguro.
- **Docker socket exposto**: risco crítico de segurança — qualquer processo dentro do container teria acesso ao daemon Docker da VPS e poderia escapar do sandbox
- **Hub central com roteamento**: ponto único de falha e superfície de ataque concentrada
- **Rodar Claude na máquina pessoal**: mistura ambiente do dev com ambiente do agente; um `rm -rf` mal sugerido afeta arquivos pessoais

Com um container por projeto, cada workspace é uma "jaula" independente: o blast radius de qualquer comando do Claude é o próprio `/workspace` daquele container. Se algo der errado, basta destruir o container e subir de novo — nada vaza pra fora.

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
