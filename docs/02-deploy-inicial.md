# 02 — Deploy Inicial

Aqui você vai aprender a criar um workspace novo do zero: preparar os pré-requisitos, configurar no Coolify e fazer o primeiro start.

---

## Pré-requisitos

- VPS com Docker e Coolify instalados
- Este repositório (template) no GitHub ou GitLab — o mesmo repo serve para todos os workspaces
- Assinatura Claude Pro ou Max ativa
- Conta no Telegram

---

## Passo 1 — Gerar o token do Claude Code

Na VPS (ou em qualquer máquina com o `claude` CLI instalado e autenticado):

```bash
claude setup-token
```

Copie o token gerado. Ele vai na variável `CLAUDE_CODE_OAUTH_TOKEN`. É um token de longa duração — pode ser reutilizado em todos os workspaces.

> **Atenção:** este token é **inference-only**. Funciona para o bot Telegram (`claude -p`) mas não habilita Remote Control. Para Remote Control, veja [05-remote-control.md](05-remote-control.md).

---

## Passo 2 — Criar o bot no Telegram

Um bot por workspace:

1. Abra uma conversa com [@BotFather](https://t.me/BotFather)
2. Envie `/newbot` e siga as instruções
3. Copie o token gerado → `TELEGRAM_TOKEN`

Para descobrir seu ID de usuário do Telegram, mande qualquer mensagem para [@userinfobot](https://t.me/userinfobot) → `ALLOWED_USER_IDS`.

---

## Passo 3 — Criar a aplicação no Coolify

### Modo Dockerfile (mais simples)

1. No Coolify: **New Application → Dockerfile**
2. Aponte para o repositório do template
3. Não precisa de porta exposta — o container não serve HTTP

### Modo Docker Compose (recomendado — garante volumes)

Crie um arquivo `docker-compose.yml` na raiz do repositório (ou use um existente):

```yaml
services:
  workspace:
    build: .
    restart: unless-stopped
    volumes:
      - workspace_data:/workspace
      - claude_config:/root/.claude
    env_file:
      - .env

volumes:
  workspace_data:
  claude_config:
```

No Coolify: **New Application → Docker Compose**, aponte para o repositório.

> Volumes nomeados são essenciais para persistir o login OAuth do Claude e o trabalho em andamento. Sem eles, tudo some no redeploy. Veja [08-persistencia-e-volumes.md](08-persistencia-e-volumes.md).

---

## Passo 4 — Configurar variáveis de ambiente

No Coolify, em **Environment Variables** (marque como *secret* as sensíveis):

### Obrigatórias

| Variável | Descrição |
|---|---|
| `TELEGRAM_TOKEN` | Token do bot (BotFather) |
| `ALLOWED_USER_IDS` | IDs autorizados, separados por vírgula |
| `CLAUDE_CODE_OAUTH_TOKEN` | Token inference-only do Claude Code |

### Opcionais

| Variável | Padrão | Descrição |
|---|---|---|
| `REPO_URL` | — | URL do repositório a clonar no primeiro start |
| `GIT_USER_NAME` | — | Nome para commits git |
| `GIT_USER_EMAIL` | — | Email para commits git |
| `SSH_PRIVATE_KEY` | — | Chave SSH privada (para repos privados) |
| `GH_TOKEN` | — | Token do GitHub — autentica `gh` e git via HTTPS |
| `WORK_DIR` | `/workspace` | Diretório de trabalho do Claude |
| `CLAUDE_TIMEOUT` | `300` | Timeout por instrução em segundos |
| `CLAUDE_MODEL` | padrão do claude | Modelo inicial (ex: `claude-opus-4-5`) |
| `CLAUDE_EFFORT` | `high` | Effort inicial: `low`, `medium`, `high` ou `max` |
| `ENABLE_BOT` | `true` | `false` para não iniciar o bot no boot |
| `CLAUDE_REMOTE_CONTROL` | `false` | `true` para subir sessão `--remote-control` no boot |
| `CLAUDE_REMOTE_CONTROL_NAME` | — | Nome da sessão exibido no claude.ai/code |

---

## Passo 5 — Configurar volumes persistentes

Se você usou o modo **Dockerfile** (sem Docker Compose), configure manualmente no Coolify em **Persistent Storage**:

| Caminho no container | Por quê |
|---|---|
| `/workspace` | Repo clonado e trabalho em andamento |
| `/root/.claude` | Histórico de conversas e credenciais OAuth do Claude |

Se usou o modo **Docker Compose**, os volumes já estão declarados no `docker-compose.yml`.

---

## Passo 6 — Deploy e teste

1. Clique em **Deploy** no Coolify
2. Aguarde o build e o start
3. No Telegram, abra o bot e envie `/start`

Se o bot responder com a mensagem de boas-vindas, está pronto.

Teste uma instrução real:

```
liste os arquivos do projeto e me diga o que ele faz
```

---

## Adicionar um novo workspace

Para cada projeto novo, repita os passos 2 a 6:
- Bot novo no BotFather
- Aplicação nova no Coolify apontando para o **mesmo repositório do template**
- Variáveis e volumes específicos daquele projeto

O template não muda. O que muda é a configuração de cada aplicação.

---

Próximo: [03-comando-setup.md](03-comando-setup.md) — ajustes pontuais depois do deploy.
