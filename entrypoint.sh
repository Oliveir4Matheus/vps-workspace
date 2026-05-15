#!/usr/bin/env bash
set -e

# --- valida variaveis obrigatorias ---
: "${TELEGRAM_TOKEN:?TELEGRAM_TOKEN nao definido}"
: "${ALLOWED_USER_IDS:?ALLOWED_USER_IDS nao definido — o bot recusaria todos}"
: "${CLAUDE_CODE_OAUTH_TOKEN:?CLAUDE_CODE_OAUTH_TOKEN nao definido}"

# --- chave ssh via env (opcional, para repos privados) ---
if [ -n "$SSH_PRIVATE_KEY" ]; then
    mkdir -p /root/.ssh
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_ed25519
    chmod 600 /root/.ssh/id_ed25519
    ssh-keyscan github.com gitlab.com >> /root/.ssh/known_hosts 2>/dev/null || true
    echo "[entrypoint] chave SSH configurada"
fi

# --- identidade git (opcional) ---
[ -n "$GIT_USER_NAME" ]  && git config --global user.name  "$GIT_USER_NAME"
[ -n "$GIT_USER_EMAIL" ] && git config --global user.email "$GIT_USER_EMAIL"

# --- autentica GitHub CLI via token (opcional) ---
# o gh le GH_TOKEN do ambiente automaticamente; setup-git faz o git usa-lo via https
if [ -n "$GH_TOKEN" ]; then
    if gh auth setup-git 2>/dev/null; then
        echo "[entrypoint] GitHub CLI autenticado via GH_TOKEN"
    else
        echo "[entrypoint] aviso: GH_TOKEN definido mas gh auth setup-git falhou"
    fi
fi

# --- clona o repo se /workspace estiver vazio ---
if [ -z "$(ls -A /workspace 2>/dev/null)" ] && [ -n "$REPO_URL" ]; then
    echo "[entrypoint] /workspace vazio — clonando $REPO_URL"
    git clone "$REPO_URL" /workspace
else
    echo "[entrypoint] /workspace ja populado ou REPO_URL ausente — pulando clone"
fi

# --- bot Telegram (opcional, default ligado) ---
case "${ENABLE_BOT,,}" in
    0|false|no|off)
        echo "[entrypoint] ENABLE_BOT desligado — pulando bot"
        ;;
    *)
        echo "[entrypoint] iniciando bot Telegram em tmux..."
        /app/bot-control.sh start || \
            echo "[entrypoint] aviso: falha ao iniciar bot (seguindo)"
        ;;
esac

# --- claude remote-control (opcional, default desligado) ---
# Se CLAUDE_REMOTE_CONTROL=true, sobe uma sessao interativa do claude
# com --remote-control dentro de tmux detached. Acessivel via claude.ai
# e tambem por 'tmux attach -t claude-rc' dentro do container.
case "${CLAUDE_REMOTE_CONTROL,,}" in
    1|true|yes|on)
        # Primeiro patcha /root/.claude.json para pular wizards (tema, trust,
        # boas-vindas). Sem isso, o claude em tmux trava esperando input.
        /app/prime-claude-config.sh || \
            echo "[entrypoint] aviso: prime-claude-config falhou (seguindo)"
        echo "[entrypoint] iniciando claude --remote-control em tmux..."
        /app/remote-control.sh start || \
            echo "[entrypoint] aviso: falha ao iniciar remote-control (seguindo)"
        echo "[entrypoint] NOTA: Remote Control exige login full-scope —"
        echo "[entrypoint] se a sessao nao aparecer em claude.ai/code, rode"
        echo "[entrypoint] 'setup' -> 'Autenticar Claude (full-scope...)'"
        ;;
esac

# Mantem o container vivo. Bot e remote-control rodam dentro de tmux e podem
# ser parados/reiniciados via 'setup' sem derrubar o container.
echo "[entrypoint] workspace pronto — PID 1 em modo guarda"
exec tail -f /dev/null
