function token() {
  const t = process.env.TELEGRAM_BOT_TOKEN;
  if (!t) throw new Error("TELEGRAM_BOT_TOKEN is not set");
  return t;
}

function chatId() {
  const id = process.env.TELEGRAM_CHAT_ID;
  if (!id) throw new Error("TELEGRAM_CHAT_ID is not set");
  return id;
}

export async function sendMessage(text, { silent = false } = {}) {
  const url = `https://api.telegram.org/bot${token()}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId(),
      text,
      disable_notification: silent,
    }),
  });
  const json = await res.json();
  if (!json.ok) {
    throw new Error(`Telegram sendMessage failed: ${json.description}`);
  }
  return json.result;
}

export async function getUpdates(offset, timeoutSeconds = 30) {
  const url = `https://api.telegram.org/bot${token()}/getUpdates`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      offset,
      timeout: timeoutSeconds,
      allowed_updates: ["message"],
    }),
  });
  const json = await res.json();
  if (!json.ok) {
    throw new Error(`Telegram getUpdates failed: ${json.description}`);
  }
  return json.result;
}

/** Only the configured chat may issue commands; everything else is ignored. */
export function isAuthorizedChat(update) {
  const id = update?.message?.chat?.id;
  return id !== undefined && String(id) === String(chatId());
}
