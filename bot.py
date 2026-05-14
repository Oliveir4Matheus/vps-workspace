import os
import asyncio
import logging
import subprocess

from telegram import Update
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    MessageHandler,
    filters,
    ContextTypes,
)

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

TELEGRAM_TOKEN = os.environ["TELEGRAM_TOKEN"]
ALLOWED_USER_IDS = {
    int(uid.strip())
    for uid in os.environ.get("ALLOWED_USER_IDS", "").split(",")
    if uid.strip()
}
WORK_DIR = os.getenv("WORK_DIR", "/workspace")
CLAUDE_TIMEOUT = int(os.getenv("CLAUDE_TIMEOUT", "300"))

if not ALLOWED_USER_IDS:
    raise SystemExit("ALLOWED_USER_IDS vazio — abortando para nao expor o bot")

# configuracao ajustavel em runtime via comandos
_config = {
    "model": os.getenv("CLAUDE_MODEL", ""),       # vazio = padrao do claude
    "effort": os.getenv("CLAUDE_EFFORT", "high"),
}

EFFORT_TOKENS = {
    "low": "4000",
    "medium": "10000",
    "high": "20000",
    "max": "32000",
}

TELEGRAM_SYSTEM_PROMPT = (
    "Voce esta respondendo atraves de um bot do Telegram. "
    "Formate toda resposta para leitura confortavel no celular: "
    "seja direto e conciso, use listas com marcadores, separe secoes com quebras "
    "de linha, evite tabelas largas e nao gere blocos de codigo muito extensos. "
    "Prefira varias mensagens curtas e bem estruturadas a um texto longo e denso."
)

# um comando por vez por chat
_locks: dict[int, asyncio.Lock] = {}
# chats que pediram /clear — proxima mensagem inicia sessao nova
_fresh: set[int] = set()


def _lock(chat_id: int) -> asyncio.Lock:
    if chat_id not in _locks:
        _locks[chat_id] = asyncio.Lock()
    return _locks[chat_id]


def is_allowed(user_id: int) -> bool:
    return user_id in ALLOWED_USER_IDS


def run_claude(instruction: str, fresh: bool) -> str:
    """Executa o Claude Code no diretorio do projeto e retorna a saida."""
    cmd = ["claude", "-p", instruction,
           "--append-system-prompt", TELEGRAM_SYSTEM_PROMPT]
    if _config["model"]:
        cmd += ["--model", _config["model"]]
    if not fresh:
        cmd.insert(1, "--continue")

    env = os.environ.copy()
    effort = _config["effort"]
    if effort in EFFORT_TOKENS:
        env["MAX_THINKING_TOKENS"] = EFFORT_TOKENS[effort]

    try:
        result = subprocess.run(
            cmd,
            cwd=WORK_DIR,
            capture_output=True,
            text=True,
            timeout=CLAUDE_TIMEOUT,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return f"⏱️ Claude excedeu o timeout de {CLAUDE_TIMEOUT}s."
    out = result.stdout.strip()
    if result.returncode != 0:
        err = result.stderr.strip()
        return f"❌ Claude retornou erro:\n{err or out or '(sem saida)'}"
    return out or "(sem saida)"


def chunk(text: str, limit: int = 4000) -> list[str]:
    if len(text) <= limit:
        return [text]
    parts = []
    while text:
        if len(text) <= limit:
            parts.append(text)
            break
        cut = text.rfind("\n", 0, limit)
        if cut == -1:
            cut = limit
        parts.append(text[:cut])
        text = text[cut:].lstrip("\n")
    return parts


async def _keep_typing(bot, chat_id: int, stop: asyncio.Event) -> None:
    """Mantem o indicador de 'digitando' enquanto o Claude trabalha."""
    while not stop.is_set():
        try:
            await bot.send_chat_action(chat_id=chat_id, action="typing")
        except Exception:
            pass
        try:
            await asyncio.wait_for(stop.wait(), timeout=4)
        except asyncio.TimeoutError:
            pass


# --- handlers ---

HELP_TEXT = (
    "🤖 Comandos disponiveis\n\n"
    "/start — mensagem de boas-vindas\n"
    "/help — esta lista de comandos\n"
    "/status — estado do workspace (branch, modelo, effort)\n"
    "/clear — inicia uma conversa nova (descarta o contexto anterior)\n"
    "/model <nome> — define o modelo: sonnet, opus, haiku ou ID completo\n"
    "/effort <nivel> — define o esforco: low, medium, high ou max\n\n"
    "Qualquer outro texto e enviado ao Claude Code como instrucao, "
    "executada no diretorio do projeto.\n\n"
    "Dica: /model e /effort sem argumento mostram o valor atual."
)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    await update.message.reply_text(
        "👋 Workspace pronto.\n"
        "Mande instrucoes e o Claude Code opera no projeto.\n\n"
        + HELP_TEXT
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    await update.message.reply_text(HELP_TEXT)


async def model_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    if not context.args:
        atual = _config["model"] or "(padrao do claude)"
        await update.message.reply_text(
            f"Modelo atual: {atual}\n\n"
            "Uso: /model <nome>\n"
            "Exemplos: /model sonnet, /model opus, /model haiku"
        )
        return
    _config["model"] = context.args[0]
    await update.message.reply_text(f"✅ Modelo definido: {_config['model']}")


async def effort_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    if not context.args:
        await update.message.reply_text(
            f"Effort atual: {_config['effort']}\n\n"
            "Uso: /effort <low|medium|high|max>"
        )
        return
    level = context.args[0].lower()
    if level not in EFFORT_TOKENS:
        await update.message.reply_text(
            "Valor invalido. Use: low, medium, high ou max"
        )
        return
    _config["effort"] = level
    await update.message.reply_text(
        f"✅ Effort definido: {level} ({EFFORT_TOKENS[level]} thinking tokens)"
    )


async def clear(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    _fresh.add(update.effective_chat.id)
    await update.message.reply_text("🗑️ Proxima mensagem inicia uma conversa nova.")


async def status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    branch = subprocess.run(
        ["git", "-C", WORK_DIR, "branch", "--show-current"],
        capture_output=True,
        text=True,
    ).stdout.strip()
    await update.message.reply_text(
        f"✅ Workspace online\n"
        f"WORK_DIR: {WORK_DIR}\n"
        f"Branch: {branch or '-'}\n"
        f"Modelo: {_config['model'] or '(padrao do claude)'}\n"
        f"Effort: {_config['effort']}"
    )


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    user_id = update.effective_user.id
    if not is_allowed(user_id):
        await update.message.reply_text("⛔ Acesso negado.")
        return

    text = (update.message.text or "").strip()
    if not text:
        return

    chat_id = update.effective_chat.id
    lock = _lock(chat_id)
    if lock.locked():
        await update.message.reply_text(
            "⏳ Ainda processando a instrucao anterior — aguarde."
        )
        return

    async with lock:
        fresh = chat_id in _fresh
        _fresh.discard(chat_id)

        stop = asyncio.Event()
        typing_task = asyncio.create_task(
            _keep_typing(context.bot, chat_id, stop)
        )
        loop = asyncio.get_running_loop()
        try:
            reply = await loop.run_in_executor(None, run_claude, text, fresh)
        except Exception as e:
            logger.exception("erro ao rodar claude")
            reply = f"❌ Erro interno: {e}"
        finally:
            stop.set()
            await typing_task

    for part in chunk(reply):
        await update.message.reply_text(part)


def main() -> None:
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(CommandHandler("clear", clear))
    app.add_handler(CommandHandler("status", status))
    app.add_handler(CommandHandler("model", model_cmd))
    app.add_handler(CommandHandler("effort", effort_cmd))
    app.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message)
    )
    logger.info("bot do workspace iniciado | WORK_DIR=%s", WORK_DIR)
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
