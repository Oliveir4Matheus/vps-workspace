# Documentação — VPS Workspace Template

Este template cria **sandboxes isolados** (um container Docker por projeto) onde agentes de IA — principalmente o **Claude Code** — podem desenvolver aplicações com liberdade, sem risco para o host nem para outros projetos. O propósito central é **vibecode seguro**: você descreve o que quer, o Claude opera no código, e o blast radius de qualquer ação fica contido no workspace.

O acesso ao agente dentro do sandbox pode ser feito por **bot do Telegram** (instruções rápidas pelo celular), por **Claude Remote Control** ([claude.ai/code](https://claude.ai/code) no browser ou app mobile), ou ambos — conforme o cenário.

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
