#!/usr/bin/env bash
# Garante que /root/.claude.json tem os flags de onboarding/trust marcados
# antes de iniciar 'claude --remote-control' em tmux. Sem isso, o claude
# trava esperando o usuario escolher tema, confirmar trust, etc — e como
# o tmux nao tem input interativo no boot, a sessao morre.
#
# Idempotente: pode rodar varias vezes sem efeito colateral.
set -e

WORK_DIR="${WORK_DIR:-/workspace}"
CFG="${CLAUDE_CONFIG_PATH:-/root/.claude.json}"

mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] || echo "{}" > "$CFG"

node -e "
const fs = require('fs');
const p = '$CFG';
const wd = '$WORK_DIR';
let d = {};
try { d = JSON.parse(fs.readFileSync(p, 'utf8')); } catch(e) {}
d.hasCompletedOnboarding = true;
d.theme = d.theme || 'dark';
d.hasSeenWelcome = true;
d.onboardingShown = true;
d.projects = d.projects || {};
d.projects[wd] = Object.assign(d.projects[wd] || {}, {
  hasTrustDialogAccepted: true,
  projectOnboardingSeenCount: 1,
  hasClaudeMdExternalIncludesApproved: true,
  hasClaudeMdExternalIncludesWarningShown: true,
});
fs.writeFileSync(p, JSON.stringify(d, null, 2));
" && echo "[prime-claude] config inicializada em $CFG"
