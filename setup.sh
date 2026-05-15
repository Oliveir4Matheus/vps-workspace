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
    "Autenticar Claude (full-scope, necessario para Remote Control)"
    "Bot: iniciar"
    "Bot: parar"
    "Bot: reiniciar"
    "Bot: ver logs (tail)"
    "Reiniciar Claude Remote Control"
    "Cloudflared: autenticar (login)"
    "Cloudflared: tunnel rapido (--url)"
    "Cloudflared: parar tunnel"
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
        "Autenticar Claude (full-scope, necessario para Remote Control)")
            echo "Este fluxo loga o claude com escopo completo (necessario para"
            echo "a feature Remote Control aparecer em claude.ai/code)."
            echo
            echo "O CLAUDE_CODE_OAUTH_TOKEN do .env e inference-only — funciona"
            echo "para o bot Telegram mas NAO habilita Remote Control."
            echo
            echo "O comando vai exibir uma URL. Abra no seu navegador, autorize,"
            echo "e o claude grava as credenciais em /root/.claude (volume"
            echo "persistente — sobrevive a redeploys)."
            echo
            read -rp "Continuar? (s/N) " c
            if [ "$c" = "s" ]; then
                claude auth login || echo "❌ Login falhou — tente novamente"
                echo
                echo "Apos sucesso, reinicie o Remote Control:"
                echo "  setup -> 'Reiniciar Claude Remote Control'"
            else
                echo "Cancelado."
            fi
            ;;
        "Bot: iniciar")
            /app/bot-control.sh start
            ;;
        "Bot: parar")
            /app/bot-control.sh stop
            ;;
        "Bot: reiniciar")
            /app/bot-control.sh restart
            ;;
        "Bot: ver logs (tail)")
            /app/bot-control.sh logs
            ;;
        "Reiniciar Claude Remote Control")
            /app/remote-control.sh restart
            ;;
        "Cloudflared: autenticar (login)")
            echo "Abrira uma URL para autorizar no navegador."
            echo "Copie a URL exibida, abra no seu computador e siga o fluxo."
            cloudflared tunnel login || echo "❌ Falha no login"
            ;;
        "Cloudflared: tunnel rapido (--url)")
            read -rp "Porta local a expor (ex: 8000): " porta
            if [ -z "$porta" ]; then
                echo "Cancelado."
            else
                echo "Subindo tunnel para http://localhost:$porta ..."
                echo "(Ctrl-C encerra; a URL trycloudflare.com sera exibida)"
                cloudflared tunnel --url "http://localhost:$porta" || true
            fi
            ;;
        "Cloudflared: parar tunnel")
            if pgrep -f "cloudflared tunnel" >/dev/null; then
                pkill -f "cloudflared tunnel" && echo "🛑 cloudflared encerrado."
            else
                echo "ℹ️  nenhum tunnel cloudflared em execucao."
            fi
            ;;
        "Ver status")
            echo "WORK_DIR: /workspace"
            git -C /workspace status 2>/dev/null || echo "(sem repositorio)"
            echo
            echo "--- Bot Telegram ---"
            /app/bot-control.sh status || true
            echo
            echo "--- Claude Remote Control ---"
            /app/remote-control.sh status || true
            echo
            echo "--- Cloudflared ---"
            if pgrep -f "cloudflared tunnel" >/dev/null; then
                echo "✅ cloudflared rodando (pid $(pgrep -f 'cloudflared tunnel' | head -1))"
            else
                echo "⏸️  cloudflared parado"
            fi
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
