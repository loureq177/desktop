#!/usr/bin/env bash
set -euo pipefail

STATUS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dictate_status"

if [ -f "$STATUS_FILE" ] && [ "$(cat "$STATUS_FILE")" = "listening" ]; then
    echo '{"text": "● Listening...", "class": "dictate-listening", "tooltip": "Dictate: Recording (Puszczono klawisz = transkrypcja)"}'
    exit 0
fi

echo '{"text": "", "class": "dictate-idle", "tooltip": "Dictate: Idle (SUPER+CTRL+S by zacząć)"}'

