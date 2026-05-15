# 07 — Casos de Uso

Aqui você vai ver cenários práticos de como o workspace pode ser configurado para diferentes necessidades.

---

## Cenário 1: Dev mobile via Telegram

**Situação:** você quer fazer ajustes rápidos num projeto a partir do celular, sem abrir o computador.

**Configuração:**

```
TELEGRAM_TOKEN=<token>
ALLOWED_USER_IDS=<seu-id>
CLAUDE_CODE_OAUTH_TOKEN=<token>
REPO_URL=https://github.com/seu-usuario/seu-projeto
GIT_USER_NAME=Seu Nome
GIT_USER_EMAIL=seu@email.com
CLAUDE_EFFORT=high
ENABLE_BOT=true
CLAUDE_REMOTE_CONTROL=false
```

**Uso típico no Telegram:**

```
qual é o status atual do projeto?
```

```
crie uma rota GET /users/:id que busca o usuário no banco
```

```
rode os testes de integração e me diga o resultado
```

```
faça commit com a mensagem "feat: adicionar rota de usuário"
```

**Vantagens:**
- Não precisa de SSH, terminal ou cliente Git no celular
- O Claude opera diretamente no codebase — não é só geração de código, é execução
- Contexto contínuo entre mensagens: você pode refinar sem repetir o contexto

**Limitações:**
- Uma instrução por vez (lock por chat)
- Respostas truncadas se muito longas (bot divide automaticamente)
- Sem saída em tempo real — você vê o resultado quando o Claude termina

---

## Cenário 2: Pareamento remoto via claude.ai/code

**Situação:** você quer uma sessão de trabalho mais longa e interativa, acessando o workspace pelo browser ou app mobile.

**Configuração:**

```
TELEGRAM_TOKEN=<token>
ALLOWED_USER_IDS=<seu-id>
CLAUDE_CODE_OAUTH_TOKEN=<token>
REPO_URL=https://github.com/seu-usuario/seu-projeto
CLAUDE_REMOTE_CONTROL=true
CLAUDE_REMOTE_CONTROL_NAME=meu-projeto
ENABLE_BOT=true
```

**Setup adicional necessário (uma vez):**

```bash
docker exec -it <container> setup
# → "Autenticar Claude (full-scope, necessário para Remote Control)"
# → abre URL no browser, autoriza
# → "Reiniciar Claude Remote Control"
```

**Uso:** acesse [claude.ai/code](https://claude.ai/code), selecione a sessão `meu-projeto` na lista.

**Vantagens sobre o bot:**
- Interface completa do Claude Code
- Saída em tempo real enquanto o Claude executa
- Possibilidade de fazer perguntas e acompanhar o raciocínio
- Melhor para tarefas longas e complexas

**Veja:** [05-remote-control.md](05-remote-control.md) para o fluxo completo.

---

## Cenário 3: Container só de acesso (sem bot)

**Situação:** você acessa o workspace principalmente via SSH ou Remote Control, não precisa do bot Telegram.

**Configuração:**

```
TELEGRAM_TOKEN=<token-placeholder>
ALLOWED_USER_IDS=<seu-id>
CLAUDE_CODE_OAUTH_TOKEN=<token>
ENABLE_BOT=false
CLAUDE_REMOTE_CONTROL=true
CLAUDE_REMOTE_CONTROL_NAME=workspace-principal
```

> `TELEGRAM_TOKEN` e `ALLOWED_USER_IDS` ainda são obrigatórios pelo entrypoint. Coloque qualquer valor válido — o bot não vai iniciar com `ENABLE_BOT=false`.

**Acesso via SSH:**

```bash
ssh usuario@ip-da-vps
docker exec -it <container> bash
# você está em /workspace com git, node, python, claude disponíveis
```

**Acesso via Remote Control:** [claude.ai/code](https://claude.ai/code) → selecione a sessão.

**Quando usar:** workspaces de longa duração onde você prefere a interface do Claude Code no browser/app ou o terminal direto.

---

## Cenário 4: Workspace + cloudflared para expor app em desenvolvimento

**Situação:** você está desenvolvendo uma API ou app web no workspace e precisa testá-la de fora da VPS (webhooks, app móvel, colega testando).

**Configuração:**

Mesma do Cenário 1 ou 2, mais:

```
# não há variável de env para o cloudflared — ele é iniciado manualmente
```

**Fluxo:**

1. No workspace, inicie o app:

```
(via bot Telegram)
inicie o servidor na porta 8000 em modo desenvolvimento
```

2. Exponha a porta:

```bash
docker exec -it <container> setup
# → "Cloudflared: tunnel rápido (--url)"
# → informe: 8000
```

3. O setup exibe uma URL `*.trycloudflare.com` — compartilhe ou use no webhook.

**Para tunnel persistente:** veja [06-cloudflared.md](06-cloudflared.md).

**Importante:** o tunnel expõe a porta publicamente. Use autenticação na sua API se os dados forem sensíveis.

---

## Comparativo rápido

| Aspecto | Bot Telegram | Remote Control | SSH direto |
|---|---|---|---|
| Interface | Mensagens | Claude Code completo | Terminal |
| Disponível no celular | Sim | Sim (app/browser) | Com cliente SSH |
| Tempo real | Não | Sim | Sim |
| Uma instrução por vez | Sim | Não | Não |
| Requer login full-scope | Não | Sim | Não |
| Precisa de `ENABLE_BOT=true` | Sim | Não | Não |

---

Próximo: [08-persistencia-e-volumes.md](08-persistencia-e-volumes.md) — por que os volumes importam e o que acontece sem eles.
