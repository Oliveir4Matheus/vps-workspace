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

# --- clona o repo se /workspace estiver vazio ---
if [ -z "$(ls -A /workspace 2>/dev/null)" ] && [ -n "$REPO_URL" ]; then
    echo "[entrypoint] /workspace vazio — clonando $REPO_URL"
    git clone "$REPO_URL" /workspace
else
    echo "[entrypoint] /workspace ja populado ou REPO_URL ausente — pulando clone"
fi

echo "[entrypoint] iniciando bot..."
exec python /app/bot.py
