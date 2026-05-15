# Documentação — VPS Workspace Template

Este template cria containers Docker de desenvolvimento isolados, cada um dedicado a um projeto/repositório. Dentro do container rodam o **Claude Code** (CLI da Anthropic) e um **bot do Telegram** que repassa instruções ao Claude — permitindo operar num codebase remotamente, do celular ou de qualquer lugar. Opcionalmente, o container também sobe uma sessão `claude --remote-control` acessível via [claude.ai/code](https://claude.ai/code).

---

## Documentos

| Arquivo | O que cobre |
|---|---|
| [01-proposito-e-arquitetura.md](01-proposito-e-arquitetura.md) | Por que o projeto existe, problema que resolve, arquitetura de processos |
| [02-deploy-inicial.md](02-deploy-inicial.md) | Criar um workspace novo do zero no Coolify |
| [03-comando-setup.md](03-comando-setup.md) | Guia detalhado do menu `setup` — todas as opções |
| [04-bot-telegram.md](04-bot-telegram.md) | Usar o bot: comandos, contexto contínuo, segurança |
| [05-remote-control.md](05-remote-control.md) | Acessar o workspace via claude.ai/code (Remote Control) |
| [06-cloudflared.md](06-cloudflared.md) | Expor portas locais do workspace via Cloudflare Tunnel |
| [07-casos-de-uso.md](07-casos-de-uso.md) | Cenários práticos de uso |
| [08-persistencia-e-volumes.md](08-persistencia-e-volumes.md) | Volumes nomeados, o que persiste e o que some sem eles |
| [09-troubleshooting.md](09-troubleshooting.md) | Sintomas comuns e como diagnosticar |

---

Para o passo a passo de configuração inicial, veja o [README.md](../README.md) do projeto.
Para criar um workspace novo, comece por [02-deploy-inicial.md](02-deploy-inicial.md).
