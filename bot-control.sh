#!/usr/bin/env bash
# Gerencia a sessao tmux que roda 'python /app/bot.py' (bot Telegram).
# Uso: bot-control {start|stop|restart|status|attach|logs}
set -e

SESSION="${BOT_TMUX_SESSION:-bot}"

session_exists() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

cmd_status() {
    if session_exists; then
        echo "✅ bot rodando (tmux session '$SESSION')"
        tmux list-sessions 2>/dev/null | grep "^$SESSION"
    else
        echo "⏸️  bot parado"
        return 1
    fi
}

cmd_start() {
    if session_exists; then
        echo "ℹ️  bot ja esta rodando — use 'restart' para reiniciar"
        return 0
    fi

    # Propaga env essencial — o bot e o claude que ele dispara precisam
    # destas vars. Sem -e, o tmux server pode usar um snapshot antigo.
    local env_args=()
    for v in TELEGRAM_TOKEN ALLOWED_USER_IDS CLAUDE_CODE_OAUTH_TOKEN \
             ANTHROPIC_API_KEY WORK_DIR CLAUDE_TIMEOUT CLAUDE_MODEL \
             CLAUDE_EFFORT HOME PATH; do
        if [ -n "${!v}" ]; then
            env_args+=( -e "$v=${!v}" )
        fi
    done

    tmux new-session -d "${env_args[@]}" -s "$SESSION" -c /app \
        "python /app/bot.py 2>&1 | tee -a /var/log/bot.log"
    sleep 1
    if session_exists; then
        echo "✅ bot iniciado (sessao '$SESSION')"
        echo "   ver tela: tmux attach -t $SESSION  (Ctrl-b d para desanexar)"
        echo "   ver log:  tail -f /var/log/bot.log"
    else
        echo "❌ falha ao iniciar — checar /var/log/bot.log"
        return 1
    fi
}

cmd_stop() {
    if session_exists; then
        tmux kill-session -t "$SESSION"
        echo "🛑 bot encerrado"
    else
        echo "ℹ️  bot ja estava parado"
    fi
}

cmd_restart() {
    cmd_stop || true
    sleep 1
    cmd_start
}

cmd_attach() {
    if ! session_exists; then
        echo "❌ bot nao esta rodando"
        return 1
    fi
    exec tmux attach -t "$SESSION"
}

cmd_logs() {
    if [ -f /var/log/bot.log ]; then
        exec tail -n 100 -f /var/log/bot.log
    else
        echo "ℹ️  /var/log/bot.log ainda nao existe (bot nunca iniciou)"
        return 1
    fi
}

case "${1:-status}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_restart ;;
    status)  cmd_status ;;
    attach)  cmd_attach ;;
    logs)    cmd_logs ;;
    *)
        echo "uso: bot-control {start|stop|restart|status|attach|logs}"
        exit 2
        ;;
esac
