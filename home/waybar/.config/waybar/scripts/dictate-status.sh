#!/usr/bin/env bash
set -euo pipefail

STATUS_FILE="/tmp/dictate_status"

if [ -f "$STATUS_FILE" ]; then
    STATUS=$(cat "$STATUS_FILE")
    if [ "$STATUS" = "listening" ]; then
        echo '{"text": "● Listening...", "class": "dictate-listening", "tooltip": "Dictate: Recording (SUPER+CTRL+S to stop)"}'
        exit 0
    fi
fi

echo '{"text": "", "class": "dictate-idle", "tooltip": "Dictate: Idle (SUPER+CTRL+S to start)"}'