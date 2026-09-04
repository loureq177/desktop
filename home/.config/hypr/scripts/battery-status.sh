#!/usr/bin/env bash

BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)

if [ -z "$BAT" ] || [ ! -d "$BAT" ]; then
    exit 0
fi

CAP=$(cat "$BAT/capacity" 2>/dev/null || echo 0)
STATUS=$(cat "$BAT/status" 2>/dev/null || echo "Discharging")

if [ "$STATUS" = "Charging" ]; then
    ICON="󰂄"
    COLOR="#3fb950"
elif [ "$STATUS" = "Full" ]; then
    ICON="󰁹"
    COLOR="#3fb950"
elif [ "$CAP" -le 10 ]; then
    ICON="󰂃"
    COLOR="#f85149"
elif [ "$CAP" -le 20 ]; then
    ICON="󰁼"
    COLOR="#d29922"
elif [ "$CAP" -ge 90 ]; then ICON="󰁹"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 80 ]; then ICON="󰂂"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 70 ]; then ICON="󰂁"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 60 ]; then ICON="󰂀"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 50 ]; then ICON="󰁿"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 40 ]; then ICON="󰁾"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 30 ]; then ICON="󰁽"; COLOR="#c9d1d9"
elif [ "$CAP" -ge 20 ]; then ICON="󰁼"; COLOR="#c9d1d9"
else ICON="󰁻"; COLOR="#c9d1d9"
fi

if [ "$COLOR" = "#c9d1d9" ]; then
    echo "$ICON $CAP%"
else
    echo "<span color='$COLOR'>$ICON $CAP%</span>"
fi
