#!/usr/bin/env bash
# Example AGYSWAP_NOTIFY_CMD target: ping a Telegram chat when an account is walled.
#   export AGYSWAP_NOTIFY_CMD='~/bin/notify-telegram.sh "$1"'
set -eu
: "${TELEGRAM_BOT_TOKEN:?}" "${TELEGRAM_CHAT_ID:?}"
curl -sS -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=agyswap: $1" >/dev/null
