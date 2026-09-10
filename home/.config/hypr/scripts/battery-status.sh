#!/usr/bin/env bash
# Waybar battery module: queries sysfs capacity/status and outputs colored icon + percentage.
set -euo pipefail

# Source centralized UI variables if available
UI_SH="${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"
if [[ -f "$UI_SH" ]]; then
    # shellcheck source=/dev/null
    source "$UI_SH"
fi

COLOR_GREEN="${UI_ACCENT_GREEN:-#3fb950}"
COLOR_WARN="${UI_WARNING:-#d29922}"
COLOR_CRIT="${UI_CRITICAL:-#f85149}"
COLOR_NORMAL="${UI_TEXT_MAIN:-#c9d1d9}"

bats=(/sys/class/power_supply/BAT*/)
BAT="${bats[0]:-}"

if [[ -z "${BAT:-}" ]] || [[ ! -d "$BAT" ]]; then
    exit 0
fi

CAP=$(cat "$BAT/capacity" 2>/dev/null || echo 0)
STATUS=$(cat "$BAT/status" 2>/dev/null || echo "Discharging")

CAP="${CAP//[^0-9]/}"
[[ -z "${CAP:-}" ]] && CAP=0

if [ "$STATUS" = "Charging" ]; then
    ICON="󰂄"
    COLOR="$COLOR_GREEN"
elif [ "$STATUS" = "Full" ]; then
    ICON="󰁹"
    COLOR="$COLOR_GREEN"
elif [ "$CAP" -le 10 ]; then
    ICON="󰂃"
    COLOR="$COLOR_CRIT"
elif [ "$CAP" -le 20 ]; then
    ICON="󰁼"
    COLOR="$COLOR_WARN"
elif [ "$CAP" -ge 90 ]; then
    ICON="󰁹"
    COLOR="$COLOR_NORMAL"
else
    # 20-29: 󰁼, 30-39: 󰁽, 40-49: 󰁾, 50-59: 󰁿, 60-69: 󰂀, 70-79: 󰂁, 80-89: 󰂂
    ICONS=(󰁼 󰁼 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂)
    ICON="${ICONS[$((CAP / 10))]}"
    COLOR="$COLOR_NORMAL"
fi

if [ "$COLOR" = "$COLOR_NORMAL" ]; then
    echo "$ICON $CAP%"
else
    echo "<span color='$COLOR'>$ICON $CAP%</span>"
fi
