#!/usr/bin/env bash
# Brightness control with the quickshell OSD. Usage: [up|down]
set -euo pipefail

ACTION="${1:-}"
case "$ACTION" in
up) brightnessctl set +10% >/dev/null 2>&1 ;;
down) brightnessctl set 10%- >/dev/null 2>&1 ;;
*) echo "brightness.sh: want up|down" >&2; exit 2 ;;
esac

# "-m" line: <device>,<device>,<current>/<max>,<percent>
PCT="$(brightnessctl -m | cut -d, -f4 | tr -dc '0-9')"
[[ -z "$PCT" ]] && PCT=0

qs ipc call osd brightness "$PCT"
