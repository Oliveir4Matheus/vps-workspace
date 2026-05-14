# VPS Workspace Template

Container de desenvolvimento isolado ("jail") com **Claude Code** operando por dentro e um **bot do Telegram** como interface. Cada projeto roda no seu próprio container, com seu próprio bot — sem hub, sem Docker socket, sem visibilidade entre workspaces.

```
Telegram  →  bot.py  →  claude --continue -p  →  /workspace (repo do projeto)
                      (tudo dentro do mesmo container isolado)
```

---

## Arquitetura

- **Um container por projeto.** Cada workspace é uma aplicação separada no Coolify.
- **Um bot por workspace.** Cada container tem seu próprio `TELEGRAM_TOKEN`.
- **Isolamento real.** O container só enxerga o próprio `/workspace`. Não tem Docker socket, não alcança outros containers.
- **Claude Code por dentro.** O bot apenas repassa a instrução; quem opera no código é o `claude` rodando no container.

---

## Pré-requisitos

- Uma VPS com Docker e Coolify
- Acesso SSH à VPS
- Uma assinatura ativa do Claude (Pro/Max) — usada via token OAuth
- Conta no Telegram

---

## Passo a passo de configuração

### 1. Suba este template para um repositório git

Crie um repositório (GitHub/GitLab) com o conteúdo desta pasta. O Coolify vai buildar o `Dockerfile` a partir dele. O mesmo repositório serve para todos os workspaces.

### 2. Gere o token do Claude Code (uma vez por VPS)

Na VPS, autenticado com sua conta Claude:

```bash
claude setup-token
```

Copie o token gerado — ele vai na variável `CLAUDE_CODE_OAUTH_TOKEN`. Esse token é de longa duração e pode ser reutilizado em todos os workspaces.

### 3. Crie um bot no Telegram (um por workspace)

1. Abra uma conversa com [@BotFather](https://t.me/BotFather)
2. Envie `/newbot` e siga as instruções
3. Copie o token gerado → `TELEGRAM_TOKEN`

### 4. Descubra seu ID de usuário do Telegram

Mande qualquer mensagem para [@userinfobot](https://t.me/userinfobot). Ele responde com seu ID numérico → `ALLOWED_USER_IDS`.

> Você pode autorizar vários IDs separando por vírgula: `123456789,987654321`

### 5. Crie a aplicação no Coolify

1. **New Application → Dockerfile**
2. Aponte para o repositório criado no passo 1
3. Em **Environment Variables**, configure (marque como *secret* as sensíveis):

   | Variável | Obrigatória | Descrição |
   |---|---|---|
   | `TELEGRAM_TOKEN` | ✅ | Token do bot (passo 3) |
   | `ALLOWED_USER_IDS` | ✅ | IDs autorizados, separados por vírgula (passo 4) |
   | `CLAUDE_CODE_OAUTH_TOKEN` | ✅ | Token do Claude Code (passo 2) |
   | `REPO_URL` | ⬜ | Repositório do projeto a clonar no primeiro start |
   | `GIT_USER_NAME` | ⬜ | Nome para os commits |
   | `GIT_USER_EMAIL` | ⬜ | Email para os commits |
   | `SSH_PRIVATE_KEY` | ⬜ | Chave SSH privada (para clonar repos privados) |
   | `WORK_DIR` | ⬜ | Diretório de trabalho (padrão: `/workspace`) |
   | `CLAUDE_TIMEOUT` | ⬜ | Timeout por instrução em segundos (padrão: `300`) |

4. Em **Persistent Storage**, adicione dois volumes:

   | Caminho no container | Por quê |
   |---|---|
   | `/workspace` | O repo clonado e o trabalho em andamento — sem isso, redeploy apaga tudo |
   | `/root/.claude` | Histórico de conversas do Claude Code — necessário para o `--continue` sobreviver a redeploys |

5. **Deploy.** O `entrypoint.sh` valida as variáveis, configura git/SSH, clona o repo (se `/workspace` estiver vazio) e sobe o bot.

### 6. Teste

Abra o Telegram, encontre seu bot e envie `/start`. Se responder, está pronto. Mande uma instrução real:

> liste os arquivos do projeto e me diga o que ele faz

---

## Repositórios privados

Para clonar um repo privado, escolha **uma** das opções:

- **Via env var:** cole a chave SSH privada em `SSH_PRIVATE_KEY` no Coolify. O entrypoint a instala automaticamente.
- **Via comando interativo:** após o deploy, rode o `setup` (veja abaixo) e cole a chave por lá.

Prefira **deploy keys por repositório** em vez de uma chave pessoal — se um container for comprometido, o dano fica restrito àquele projeto.

---

## Comandos do bot

| Comando | Ação |
|---|---|
| `/start` | Mensagem de boas-vindas |
| `/help` | Lista todos os comandos disponíveis |
| `/clear` | A próxima mensagem inicia uma conversa nova (sem `--continue`) |
| `/status` | Mostra `WORK_DIR`, branch, modelo e effort atuais |
| `/model <nome>` | Define o modelo do Claude (`sonnet`, `opus`, `haiku` ou ID completo). Sem argumento, mostra o atual |
| `/effort <nível>` | Define o esforço: `low`, `medium`, `high` ou `max`. Sem argumento, mostra o atual |
| *(qualquer texto)* | Repassado ao Claude Code como instrução |

Comportamento:
- **Contexto contínuo:** mensagens em sequência mantêm o contexto via `claude --continue`.
- **Uma por vez:** enquanto uma instrução processa, novas mensagens são recusadas.
- **Respostas para Telegram:** todas as instruções recebem um system prompt fixo (`--append-system-prompt`) que orienta o Claude a responder de forma estruturada e concisa, adequada para leitura no celular.
- **Modelo e effort:** ajustáveis em runtime via `/model` e `/effort`, ou definidos no start via `CLAUDE_MODEL` e `CLAUDE_EFFORT`. O effort é aplicado via `MAX_THINKING_TOKENS` (low=4k, medium=10k, high=20k, max=32k).
- **Segurança:** somente IDs em `ALLOWED_USER_IDS` são atendidos. Sem essa variável, o bot **não inicia**.

---

## Restringir o bot apenas a você

O bot já recusa qualquer pessoa fora de `ALLOWED_USER_IDS`, mas o ideal é fechar todas as portas. Faça o seguinte:

### 1. Só o seu ID na allowlist

Em `ALLOWED_USER_IDS`, deixe **apenas o seu ID** — nada de vírgulas, nada de outros IDs:

```
ALLOWED_USER_IDS=123456789
```

Qualquer mensagem de outro ID recebe "⛔ Acesso negado" e nada é executado. Esta é a barreira principal.

### 2. Bloqueie o bot em grupos (BotFather)

Por padrão um bot pode ser adicionado a grupos. Desative isso para que ele só funcione em conversa privada com você:

1. Abra o [@BotFather](https://t.me/BotFather)
2. `/mybots` → selecione o bot → **Bot Settings** → **Allow Groups?** → **Turn off**

### 3. Mantenha a privacidade de grupo ativada (BotFather)

Garante que, mesmo se de alguma forma entrar num grupo, o bot não leia as mensagens:

- **Bot Settings** → **Group Privacy** → **Turn on**

### 4. Não divulgue o username do bot

O token e o username são o que dá acesso à *tentativa* de uso. Mesmo que alguém descubra o username, sem o ID na allowlist não consegue nada — mas não há motivo para facilitar. Não coloque o bot em listas públicas nem compartilhe o username.

### 5. Trate o `TELEGRAM_TOKEN` como senha

Quem tem o token **controla o bot**. Mantenha como *secret* no Coolify, nunca commite no repositório. Se vazar, gere outro no BotFather (`/mybots` → **API Token** → **Revoke**).

> Resumo: a segurança real é `ALLOWED_USER_IDS` com só o seu ID + o `TELEGRAM_TOKEN` protegido. Os passos 2-4 só reduzem a superfície de exposição.

---

## Comando `setup` (configuração interativa)

Para ajustes pontuais depois do deploy, acesse a VPS via SSH e rode:

```bash
docker exec -it <nome-do-container> setup
```

Menu disponível:
- Clonar / trocar repositório
- Configurar chave SSH (colar)
- Configurar identidade git
- Testar Claude Code
- Ver status

---

## Acesso manual ao container

```bash
ssh usuario@ip-da-vps
docker exec -it <nome-do-container> bash
```

Você cai dentro do `/workspace`, com `git`, `python`, `node` e `claude` disponíveis.

---

## Adicionar um novo workspace

Repita os passos **3 a 6** para cada projeto novo: um bot novo no BotFather, uma aplicação nova no Coolify apontando para o mesmo repositório do template, com as env vars e volumes daquele projeto. O template não muda.

---

## Estrutura do projeto

```
vps-workspace-template/
├── Dockerfile        # debian-slim + Python + Node + Git + Claude Code + bot
├── bot.py            # Telegram → claude --continue -p (lock por chat, typing contínuo)
├── entrypoint.sh     # valida envs, configura SSH/git, clona repo, sobe o bot
├── setup.sh          # comando 'setup' interativo
├── requirements.txt
└── .env.example
```

---

## Solução de problemas

| Sintoma | Causa provável |
|---|---|
| Container reinicia em loop | Falta uma variável obrigatória — veja os logs do `entrypoint.sh` |
| Bot não responde | `TELEGRAM_TOKEN` errado, ou seu ID não está em `ALLOWED_USER_IDS` |
| "Acesso negado" no chat | Seu ID do Telegram não está em `ALLOWED_USER_IDS` |
| Claude retorna erro de auth | `CLAUDE_CODE_OAUTH_TOKEN` inválido ou expirado — gere outro com `claude setup-token` |
| Trabalho some após redeploy | Faltou o volume persistente em `/workspace` |
| `--continue` não lembra do contexto | Faltou o volume persistente em `/root/.claude` |
| `git clone` falha em repo privado | Configure `SSH_PRIVATE_KEY` ou use o comando `setup` |
# vps-workspace
