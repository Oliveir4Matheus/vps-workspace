#!/usr/bin/env bash
# Gerencia a sessao tmux que roda 'claude --remote-control'.
# Uso: remote-control {start|stop|restart|status|attach}
set -e

SESSION="${CLAUDE_RC_TMUX_SESSION:-claude-rc}"
WORK_DIR="${WORK_DIR:-/workspace}"

# monta o comando do claude, incluindo --remote-control [name] se informado
build_cmd() {
    local cmd="claude --remote-control"
    if [ -n "$CLAUDE_REMOTE_CONTROL_NAME" ]; then
        cmd="$cmd $(printf '%q' "$CLAUDE_REMOTE_CONTROL_NAME")"
    fi
    echo "$cmd"
}

session_exists() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

cmd_status() {
    if session_exists; then
        echo "✅ sessao '$SESSION' ativa"
        tmux list-sessions 2>/dev/null | grep "^$SESSION"
    else
        echo "⏸️  sessao '$SESSION' nao esta rodando"
        return 1
    fi
}

cmd_start() {
    if session_exists; then
        echo "ℹ️  sessao '$SESSION' ja esta rodando — use 'restart' para reiniciar"
        return 0
    fi
    local cmd
    cmd="$(build_cmd)"

    # Propaga env essencial para a sessao tmux. Sem isso, o tmux server pode
    # entregar o comando sem CLAUDE_CODE_OAUTH_TOKEN e o claude cai no login.
    local env_args=()
    [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && \
        env_args+=( -e "CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN" )
    [ -n "$ANTHROPIC_API_KEY" ] && \
        env_args+=( -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" )
    [ -n "$HOME" ] && env_args+=( -e "HOME=$HOME" )
    [ -n "$PATH" ] && env_args+=( -e "PATH=$PATH" )

    tmux new-session -d "${env_args[@]}" -s "$SESSION" -c "$WORK_DIR" "$cmd"
    sleep 1
    if session_exists; then
        echo "✅ remote-control iniciado em tmux (sessao '$SESSION')"
        echo "   ver tela: tmux attach -t $SESSION  (Ctrl-b d para desanexar)"
    else
        echo "❌ falha ao iniciar — claude saiu imediatamente"
        return 1
    fi
}

cmd_stop() {
    if session_exists; then
        tmux kill-session -t "$SESSION"
        echo "🛑 sessao '$SESSION' encerrada"
    else
        echo "ℹ️  nada para parar — sessao '$SESSION' nao existia"
    fi
}

cmd_restart() {
    cmd_stop || true
    sleep 1
    cmd_start
}

cmd_attach() {
    if ! session_exists; then
        echo "❌ sessao '$SESSION' nao esta rodando"
        return 1
    fi
    exec tmux attach -t "$SESSION"
}

case "${1:-status}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_restart ;;
    status)  cmd_status ;;
    attach)  cmd_attach ;;
    *)
        echo "uso: remote-control {start|stop|restart|status|attach}"
        exit 2
        ;;
esac
