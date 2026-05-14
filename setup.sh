#!/usr/bin/env bash
# Comando interativo de configuracao do workspace.
# Uso: docker exec -it <container> setup
set -e

echo "=== Setup do Workspace ==="
echo

PS3="Escolha uma opcao: "
options=(
    "Clonar / trocar repositorio"
    "Autenticar GitHub CLI (colar token)"
    "Clonar repositorios (GitHub CLI)"
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
        "Autenticar GitHub CLI (colar token)")
            echo "Cole o GitHub Personal Access Token (entrada oculta) e tecle Enter:"
            read -rs token
            echo
            if [ -z "$token" ]; then
                echo "Cancelado (token vazio)."
            else
                if echo "$token" | gh auth login --with-token 2>/dev/null \
                    && gh auth setup-git 2>/dev/null; then
                    echo "✅ GitHub CLI autenticado e git configurado."
                else
                    echo "❌ Falha na autenticacao — verifique o token e os escopos."
                fi
            fi
            unset token
            ;;
        "Clonar repositorios (GitHub CLI)")
            if ! gh auth status >/dev/null 2>&1; then
                echo "❌ gh nao autenticado."
                echo "   Use a opcao 'Autenticar GitHub CLI' ou defina GH_TOKEN no Coolify."
            else
                echo "Buscando seus repositorios..."
                mapfile -t repos < <(gh repo list --limit 200 \
                    --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null)
                if [ "${#repos[@]}" -eq 0 ]; then
                    echo "Nenhum repositorio encontrado."
                else
                    echo
                    for i in "${!repos[@]}"; do
                        printf "  %2d) %s\n" "$((i + 1))" "${repos[$i]}"
                    done
                    echo
                    read -rp "Numeros para clonar (separados por espaco): " -a escolhas
                    for n in "${escolhas[@]}"; do
                        idx=$((n - 1))
                        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#repos[@]}" ]; then
                            repo="${repos[$idx]}"
                            nome="${repo##*/}"
                            echo "→ clonando $repo em /workspace/$nome"
                            gh repo clone "$repo" "/workspace/$nome" \
                                || echo "  ❌ falhou: $repo"
                        else
                            echo "  ignorado: '$n' (numero invalido)"
                        fi
                    done
                    echo "✅ Concluido."
                fi
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
