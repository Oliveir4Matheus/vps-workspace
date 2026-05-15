# 04 — Bot do Telegram

Aqui você vai aprender a usar o bot: quais comandos existem, como funciona o contexto contínuo, como o lock por chat funciona e como o bot formata as respostas para o celular.

---

## Comandos disponíveis

| Comando | Ação |
|---|---|
| `/start` | Mensagem de boas-vindas com lista de comandos |
| `/help` | Lista todos os comandos disponíveis |
| `/status` | Mostra `WORK_DIR`, branch atual, modelo e effort configurados |
| `/clear` | Marca que a próxima mensagem inicia uma conversa nova (sem `--continue`) |
| `/model <nome>` | Define o modelo do Claude. Sem argumento, mostra o atual |
| `/effort <nível>` | Define o effort de thinking. Sem argumento, mostra o atual |
| *(qualquer texto)* | Repassado ao Claude Code como instrução |

---

## Mandando instruções

Qualquer mensagem que não seja um comando é enviada diretamente ao Claude Code, que executa no diretório `/workspace` (ou `WORK_DIR` se definido).

Exemplos práticos:

```
liste os arquivos do projeto e me diga o que ele faz
```

```
corrija o bug de autenticação na rota /api/login
```

```
rode os testes e me diga o que está quebrando
```

```
crie um endpoint GET /health que retorna {"status": "ok"}
```

O Claude tem acesso completo ao sistema de arquivos do `/workspace`, pode rodar comandos shell, instalar dependências e fazer commits.

---

## Contexto contínuo (`--continue`)

Por padrão, cada mensagem usa `claude --continue`, que mantém o contexto da conversa anterior. Isso significa que:

- O Claude lembra do que foi feito nas mensagens anteriores
- Você pode fazer refinamentos: "agora adicione tratamento de erros"
- O contexto persiste enquanto o volume `/root/.claude` existir — inclusive após redeploys

Para iniciar uma conversa do zero (sem contexto anterior), use `/clear` antes da próxima mensagem. O `/clear` apenas marca a flag — a próxima mensagem será enviada sem `--continue`, e as subsequentes voltam a usar `--continue`.

---

## Lock por chat

O bot processa uma instrução por vez, por chat. Se você mandar uma segunda mensagem enquanto a primeira ainda está sendo processada, o bot responde:

> "Ainda processando a instrução anterior — aguarde."

Isso evita condições de corrida em que o Claude recebe duas instruções conflitantes ao mesmo tempo. Não há fila — a mensagem recusada é descartada.

---

## Indicador "digitando"

Enquanto o Claude processa, o bot mantém o indicador "digitando..." ativo no Telegram (atualizado a cada 4 segundos). Isso confirma que a instrução foi recebida e está sendo processada.

---

## Modelo e effort

### `/model`

Define qual modelo do Claude será usado nas próximas instruções:

```
/model sonnet
/model opus
/model haiku
/model claude-opus-4-5-20251101
```

Sem argumento, exibe o modelo atual. Modelo vazio = padrão do `claude` CLI.

O valor inicial vem da variável `CLAUDE_MODEL`. Se não definida, usa o padrão do Claude Code.

### `/effort`

Define o nível de thinking (tokens de raciocínio interno):

| Nível | Thinking tokens |
|---|---|
| `low` | 4.000 |
| `medium` | 10.000 |
| `high` | 20.000 (padrão) |
| `max` | 32.000 |

```
/effort low
/effort max
```

O valor é aplicado via variável de ambiente `MAX_THINKING_TOKENS` passada ao subprocess do Claude. Instruções simples não precisam de `high` — use `low` para economizar quando a tarefa for direta.

---

## System prompt fixo para Telegram

Todas as instruções recebem um `--append-system-prompt` que orienta o Claude a responder adequadamente para leitura em celular:

- Respostas diretas e concisas
- Listas com marcadores
- Seções separadas por quebras de linha
- Sem tabelas largas
- Sem blocos de código muito extensos

Isso não substitui seu system prompt do projeto — é adicionado por cima.

---

## Respostas longas

Se a resposta do Claude ultrapassar 4.000 caracteres (limite de mensagem do Telegram), o bot divide automaticamente em partes, quebrando em limites de linha.

---

## Segurança

O bot verifica `ALLOWED_USER_IDS` em **toda** mensagem recebida — tanto comandos quanto texto livre. Se o ID do remetente não estiver na lista, a resposta é "Acesso negado" e nada é executado.

Se `ALLOWED_USER_IDS` estiver vazio, o bot **não inicia** — falha no boot com erro explícito.

Para restringir o acesso ao máximo:
- Deixe apenas o seu ID em `ALLOWED_USER_IDS`
- No BotFather, desative "Allow Groups" para o bot
- Nunca compartilhe o `TELEGRAM_TOKEN` — quem tem o token controla o bot

---

## Gerenciar o bot

O bot roda numa sessão tmux chamada `bot`. Para gerenciar:

```bash
docker exec -it <container> bot-control status
docker exec -it <container> bot-control restart
docker exec -it <container> bot-control logs
docker exec -it <container> bot-control attach   # Ctrl-b d para desanexar
```

Ou via menu: `docker exec -it <container> setup` → opções Bot.

---

Próximo: [05-remote-control.md](05-remote-control.md) — acessar o workspace via claude.ai/code.
