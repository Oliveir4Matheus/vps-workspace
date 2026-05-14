#!/usr/bin/env bash
# Comando interativo de configuracao do workspace.
# Uso: docker exec -it <container> setup
set -e

echo "=== Setup do Workspace ==="
echo

PS3="Escolha uma opcao: "
options=(
    "Clonar / trocar repositorio"
    "Configurar chave SSH (colar)"
    "Configurar identidade git"
    "Testar Claude Code"
    "Ver status"
    "Sair"
)

select opt in "${options[@]}"; do
    case "$opt" in
        "Clonar / trocar repositorio")
            read -rp "URL do repositorio: " repo
            read -rp "Isso vai limpar /workspace. Confirma? (s/N) " c
            if [ "$c" = "s" ]; then
                rm -rf /workspace/* /workspace/.[!.]* 2>/dev/null || true
                git clone "$repo" /workspace
                echo "✅ Clonado."
            else
                echo "Cancelado."
            fi
            ;;
        "Configurar chave SSH (colar)")
            mkdir -p /root/.ssh
            echo "Cole a chave privada e finalize com Ctrl-D:"
            cat > /root/.ssh/id_ed25519
            chmod 600 /root/.ssh/id_ed25519
            ssh-keyscan github.com gitlab.com >> /root/.ssh/known_hosts 2>/dev/null || true
            echo "✅ Chave SSH configurada."
            ;;
        "Configurar identidade git")
            read -rp "Nome: " n
            read -rp "Email: " e
            git config --global user.name "$n"
            git config --global user.email "$e"
            echo "✅ Identidade git configurada."
            ;;
        "Testar Claude Code")
            claude -p "responda apenas: ok" \
                || echo "❌ Falhou — verifique CLAUDE_CODE_OAUTH_TOKEN"
            ;;
        "Ver status")
            echo "WORK_DIR: /workspace"
            git -C /workspace status 2>/dev/null || echo "(sem repositorio)"
            ;;
        "Sair")
            break
            ;;
        *)
            echo "Opcao invalida"
            ;;
    esac
    echo
done
