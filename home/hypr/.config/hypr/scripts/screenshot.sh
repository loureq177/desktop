#!/bin/bash

MODE=$1
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

if [ "$MODE" = "region" ]; then
    grim -g "$(slurp)" "$FILE"
else
    grim "$FILE"
fi

# Jeśli zrzut został anulowany (np. escape w slurp), to zakończ
if [ ! -f "$FILE" ]; then
    exit 0
fi

# Skopiuj do schowka
wl-copy < "$FILE"

# Wyślij powiadomienie i czekaj na akcję użytkownika
ACTION=$(notify-send -t 5000 -a "Screenshot" -i "$FILE" -A "default=Edytuj" -A "edit=Edytuj w Satty" "Zrzut ekranu zapisany" "Skopiowano do schowka. Kliknij, aby edytować.")

if [ "$ACTION" = "default" ] || [ "$ACTION" = "edit" ]; then
    satty --filename "$FILE" --fullscreen --output-filename "$FILE"
fi
