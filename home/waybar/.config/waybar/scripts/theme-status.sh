#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.cache/theme-mode"

if [[ -f "$STATE_FILE" ]]; then
	mode=$(cat "$STATE_FILE")
else
	mode="dark"
fi

if [[ "$mode" == "dark" ]]; then
	echo '{"text": "", "alt": "dark", "class": "dark", "tooltip": "Dark mode"}'
else
	echo '{"text": "", "alt": "light", "class": "light", "tooltip": "Light mode — click to toggle"}'
fi
