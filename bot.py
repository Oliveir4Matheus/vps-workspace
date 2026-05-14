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
    cmd = ["claude", "-p", instruction]
    if not fresh:
        cmd.insert(1, "--continue")
    try:
        result = subprocess.run(
            cmd,
            cwd=WORK_DIR,
            capture_output=True,
            text=True,
            timeout=CLAUDE_TIMEOUT,
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

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("⛔ Acesso negado.")
        return
    await update.message.reply_text(
        "👋 Workspace pronto.\n"
        "Mande instrucoes e o Claude Code opera no projeto.\n\n"
        "/clear — comeca uma conversa nova\n"
        "/status — estado do workspace"
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
        f"WORK_DIR: `{WORK_DIR}`\n"
        f"Branch: `{branch or '—'}`",
        parse_mode="Markdown",
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
    app.add_handler(CommandHandler("clear", clear))
    app.add_handler(CommandHandler("status", status))
    app.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message)
    )
    logger.info("bot do workspace iniciado | WORK_DIR=%s", WORK_DIR)
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
