# 09 — Troubleshooting

Aqui você vai encontrar sintomas comuns, causas prováveis e como diagnosticar e resolver cada um.

---

## Comandos úteis de diagnóstico

```bash
# entrar no container
docker exec -it <container> bash

# ver sessões tmux ativas
tmux ls

# ver o que está na tela de uma sessão
tmux capture-pane -t bot -p
tmux capture-pane -t claude-rc -p

# status do bot
bot-control status

# status do remote-control
remote-control status

# status do Claude (credenciais)
claude auth status

# logs do bot
tail -f /var/log/bot.log

# logs do container (entrypoint)
docker logs <container>

# verificar variáveis de ambiente dentro do container
env | grep -E 'TELEGRAM|CLAUDE|ALLOWED|ENABLE|GH_'
```

---

## Problemas com o bot Telegram

### Sintoma: bot não responde a nenhuma mensagem

**Causas a verificar, em ordem:**

1. **`ENABLE_BOT` está desligado?**
   ```bash
   docker exec -it <container> env | grep ENABLE_BOT
   ```
   Se `ENABLE_BOT=false`, o bot não sobe no boot. Inicie manualmente:
   ```bash
   docker exec -it <container> bot-control start
   ```

2. **A sessão tmux está rodando?**
   ```bash
   docker exec -it <container> bot-control status
   ```
   Se não estiver: `bot-control start`. Se iniciar mas cair imediatamente, cheque os logs.

3. **Seu ID está em `ALLOWED_USER_IDS`?**
   Mande qualquer mensagem. Se o bot responder "Acesso negado", seu ID não está na lista.
   Verifique: no Telegram, mande uma mensagem para [@userinfobot](https://t.me/userinfobot) para confirmar seu ID.
   Corrija `ALLOWED_USER_IDS` no Coolify e faça redeploy (ou reinicie o bot para recarregar as envs).

4. **`TELEGRAM_TOKEN` está correto?**
   Um token errado faz o bot iniciar mas falhar ao conectar à API do Telegram. Veja nos logs:
   ```bash
   docker exec -it <container> bot-control logs
   ```
   Procure por `Unauthorized` ou `Invalid token`.

### Sintoma: bot responde "Acesso negado"

Seu ID do Telegram não está em `ALLOWED_USER_IDS`. Verifique o ID correto com [@userinfobot](https://t.me/userinfobot) e atualize a variável no Coolify.

### Sintoma: bot aceita a mensagem mas não responde (fica "digitando" para sempre)

O Claude Code está travado ou excedeu o timeout.

```bash
docker exec -it <container> bot-control logs
```

Causas comuns:
- `CLAUDE_CODE_OAUTH_TOKEN` inválido ou expirado — gere outro com `claude setup-token`
- O Claude ficou preso num loop ou comando que não termina — reinicie o bot
- Timeout muito baixo (`CLAUDE_TIMEOUT`) para a tarefa — aumente o valor

### Sintoma: bot para de responder após algumas mensagens

O lock por chat pode estar preso (instrução que não terminou). Reinicie o bot:

```bash
docker exec -it <container> bot-control restart
```

---

## Problemas com o Remote Control

### Sintoma: Remote Control não aparece em claude.ai/code

Causa: o login full-scope não foi feito, ou as credenciais não estão sendo usadas.

**Diagnóstico:**

```bash
docker exec -it <container> claude auth status
```

Se mostrar "inference-only" ou "not authenticated", o login full-scope não foi feito.

```bash
docker exec -it <container> setup
# → "Autenticar Claude (full-scope, necessário para Remote Control)"
```

Após o login, reinicie a sessão:

```bash
docker exec -it <container> remote-control restart
```

### Sintoma: sessão tmux `claude-rc` aparece como ativa mas não conecta

O `CLAUDE_CODE_OAUTH_TOKEN` pode estar sendo injetado no ambiente da sessão, fazendo o Claude usar o token inference-only ao invés das credenciais full-scope. O `remote-control.sh` faz `unset` dessas variáveis — se você reiniciou a sessão manualmente sem usar `remote-control`, pode ter esquecido o unset.

Reinicie sempre pelo script:

```bash
docker exec -it <container> remote-control restart
```

### Sintoma: sessão tmux `claude-rc` cai imediatamente após iniciar

O Claude pode ter travado num wizard de primeira execução (tema, boas-vindas, trust) e morrido.

**Diagnóstico:**

```bash
docker exec -it <container> tmux capture-pane -t claude-rc -p 2>/dev/null || echo "sessao nao existe"
```

Se a sessão não existe, o Claude abriu e fechou. Rode o `prime-claude-config.sh` manualmente e reinicie:

```bash
docker exec -it <container> /app/prime-claude-config.sh
docker exec -it <container> remote-control restart
```

Veja o arquivo `/app/prime-claude-config.sh` para entender quais flags ele define.

---

## Problemas com persistência

### Sintoma: trabalho some após redeploy

Os volumes não estão configurados. Verifique:

```bash
docker inspect <container> | grep -A 5 '"Mounts"'
```

Se a lista de mounts estiver vazia ou não incluir `/workspace`, configure os volumes no Coolify (Persistent Storage) ou no `docker-compose.yml`.

Veja [08-persistencia-e-volumes.md](08-persistencia-e-volumes.md).

### Sintoma: `--continue` não lembra de nada

O volume `/root/.claude` não está configurado — o histórico de conversas é descartado no redeploy.

Configure o volume e o `--continue` vai funcionar a partir do próximo start.

---

## Problemas com o container

### Sintoma: container reinicia em loop

O `entrypoint.sh` falhou numa variável obrigatória. Verifique os logs:

```bash
docker logs <container> --tail 50
```

Procure por linhas como:
```
entrypoint.sh: line X: TELEGRAM_TOKEN: nao definido
```

Corrija a variável no Coolify e faça redeploy.

### Sintoma: `setup` não está disponível no container

O script pode não ter sido instalado. Verifique o Dockerfile. Em modo de desenvolvimento, você pode rodar diretamente:

```bash
docker exec -it <container> bash /app/setup.sh
```

---

## Problemas com git e repositórios

### Sintoma: `git clone` falha em repo privado

Escolha uma das opções:
- Defina `GH_TOKEN` no Coolify (para repos do GitHub via HTTPS)
- Defina `SSH_PRIVATE_KEY` no Coolify (para qualquer host Git via SSH)
- Use `setup` → "Autenticar GitHub CLI" ou "Configurar chave SSH"

### Sintoma: commits sem nome/email

Configure a identidade:
```bash
docker exec -it <container> setup
# → "Configurar identidade git"
```

Ou defina `GIT_USER_NAME` e `GIT_USER_EMAIL` no Coolify.

---

## Referência rápida de diagnóstico

| Sintoma | Primeiro comando a rodar |
|---|---|
| Bot não responde | `docker exec -it <container> bot-control status` |
| Remote Control sumiu | `docker exec -it <container> remote-control status` |
| Claude não autentica | `docker exec -it <container> claude auth status` |
| Sessão tmux travada | `docker exec -it <container> tmux ls` |
| Ver o que o Claude está fazendo | `docker exec -it <container> tmux attach -t bot` |
| Container caindo em loop | `docker logs <container> --tail 50` |
| Volume não montado | `docker inspect <container> \| grep Mounts -A 10` |
