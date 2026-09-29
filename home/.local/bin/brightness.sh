#!/usr/bin/env bash
# Brightness control with the quickshell OSD. Usage: [up|down]
set -euo pipefail

command -v brightnessctl >/dev/null 2>&1 || exit 0
brightnessctl -c backlight -m 2>/dev/null | grep -q . || exit 0

ACTION="${1:-}"
case "$ACTION" in
up) brightnessctl set +10% >/dev/null 2>&1 ;;
down) brightnessctl set 10%- >/dev/null 2>&1 ;;
*) echo "brightness.sh: want up|down" >&2; exit 2 ;;
esac

# "-m" line: <device>,<device>,<current>/<max>,<percent>
# Take the first backlight device only: -m prints one line per device and
# concatenating all percents (e.g. 50% + 67% -> "5067") breaks the OSD.
PCT="$(brightnessctl -c backlight -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -dc '0-9')"
[[ -z "$PCT" ]] && PCT=0

qs ipc call osd brightness "$PCT"
# Keep the QuickSettings slider in sync (it polls every 3s).
qs ipc call quicksettings refresh >/dev/null 2>&1 || true
