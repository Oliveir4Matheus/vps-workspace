# 08 — Persistência e Volumes

Aqui você vai entender por que dois volumes são essenciais, o que acontece sem eles e como configurá-los tanto no modo Dockerfile quanto no modo Docker Compose do Coolify.

---

## Por que volumes importam

Por padrão, um container Docker não persiste nada. Toda modificação no sistema de arquivos é descartada quando o container é recriado — e no Coolify isso acontece em todo redeploy.

Este workspace tem dois diretórios que precisam sobreviver a redeploys:

### `/workspace`

O repositório clonado e todo o trabalho em andamento. Sem volume:
- Todo redeploy apaga o código clonado
- Arquivos criados/editados pelo Claude são perdidos
- Commits não enviados (não feitos push) somem

### `/root/.claude`

O diretório de estado do Claude Code. Contém:
- `conversation.jsonl` — histórico de conversas (necessário para `--continue` funcionar)
- `.credentials.json` — credenciais OAuth do login full-scope (Remote Control)
- `.claude.json` — configurações do Claude (onboarding, tema, trust por projeto)

Sem volume:
- O `--continue` do bot Telegram não lembra de nada entre redeploys
- O login full-scope (Remote Control) precisa ser refeito a cada redeploy
- Os flags de onboarding somem — se o `prime-claude-config.sh` não rodar antes, o claude pode travar

---

## O que acontece sem volumes — por sintoma

| Sintoma | Causa |
|---|---|
| `/workspace` vazio após redeploy | Volume de `/workspace` não configurado |
| `--continue` não lembra do contexto | Volume de `/root/.claude` não configurado |
| Remote Control pede novo login após redeploy | Volume de `/root/.claude` não configurado |
| Claude trava no boot | `prime-claude-config.sh` não rodou (flags someram) |

---

## Configurar volumes no modo Dockerfile (Coolify)

No Coolify, na configuração da aplicação, acesse **Persistent Storage** e adicione:

| Source (volume nomeado) | Destination (container) |
|---|---|
| `workspace_data` | `/workspace` |
| `claude_config` | `/root/.claude` |

O Coolify cria os volumes nomeados automaticamente. Eles sobrevivem a redeploys, rebuilds e atualizações da aplicação.

---

## Configurar volumes no modo Docker Compose (recomendado)

Declare os volumes diretamente no `docker-compose.yml`:

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

Volumes nomeados no Docker Compose são gerenciados pelo Docker — persistem entre `docker-compose down` e `docker-compose up`. Para removê-los explicitamente: `docker-compose down -v` (destrói os volumes, cuidado).

---

## Migrar de Dockerfile para Docker Compose no Coolify

Se você criou a aplicação no modo Dockerfile e quer migrar para Docker Compose (para ter os volumes declarados em código):

1. No Coolify, na aplicação, acesse **Configuration**
2. Mude o tipo de build de "Dockerfile" para "Docker Compose"
3. Aponte para o arquivo `docker-compose.yml` no repositório
4. Salve e faça redeploy

Os volumes existentes (criados via Persistent Storage do Coolify) **não são afetados** pela mudança de modo — continuam existindo e o Docker Compose os reutiliza se os nomes coincidirem.

> Verifique os nomes antes de migrar. Se o volume criado pelo Coolify se chama `workspace_data` e o `docker-compose.yml` usa `workspace_data`, eles são o mesmo volume.

---

## Verificar se os volumes estão montados

Dentro do container:

```bash
docker exec -it <container> bash
df -h /workspace          # deve mostrar um filesystem separado
ls -la /root/.claude      # deve listar arquivos se o Claude já foi usado
```

Via Docker:

```bash
docker inspect <container> | grep -A 20 '"Mounts"'
```

---

## Backup dos volumes

Para fazer backup dos dados do workspace:

```bash
# backup do /workspace
docker run --rm -v workspace_data:/data -v $(pwd):/backup \
    alpine tar czf /backup/workspace-backup.tar.gz -C /data .

# backup do /root/.claude
docker run --rm -v claude_config:/data -v $(pwd):/backup \
    alpine tar czf /backup/claude-backup.tar.gz -C /data .
```

Para restaurar, inverta a direção do tar.

---

Próximo: [09-troubleshooting.md](09-troubleshooting.md) — diagnóstico de problemas comuns.
