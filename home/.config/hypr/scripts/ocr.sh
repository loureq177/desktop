#!/usr/bin/env bash
# Interactive screen OCR: crops area via slurp/grim, runs tesseract (pol+eng), and copies to clipboard.
set -euo pipefail

# Source centralized UI variables if available
UI_SH="${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"
if [[ -f "$UI_SH" ]]; then
    # shellcheck source=/dev/null
    source "$UI_SH"
fi
SLURP_OPTS=("${SLURP_ARGS[@]:--d -b "#0d1117b0" -c "#58a6ff" -s "#58a6ff20" -w 2}")

LOCKFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ocr_slurp.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

play_sound() { "${HOME}/.local/bin/play-sound" "$@" 2>/dev/null || true; }

TMP_DIR=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/ocr.XXXXXX")
TMP_IMG="$TMP_DIR/crop.png"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Select region
GEOM=$(slurp "${SLURP_OPTS[@]}") || exit 0

# Capture screenshot of selected region
grim -g "$GEOM" "$TMP_IMG" || exit 0

if [ ! -s "$TMP_IMG" ]; then
    exit 0
fi

# Detect installed tesseract languages (support pol and eng)
LANGS="eng"
if tesseract --list-langs 2>/dev/null | grep -q "^pol$"; then
    LANGS="pol+eng"
fi

# Run OCR
TEXT=$(tesseract "$TMP_IMG" stdout -l "$LANGS" -c preserve_interword_spaces=1 2>/dev/null || true)

# Trim leading and trailing whitespace
TRIMMED_TEXT="$(printf '%s' "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

# Release lock before clipboard operations
exec 200>&-

if [ -n "$TRIMMED_TEXT" ]; then
    printf "%s" "$TRIMMED_TEXT" | wl-copy
    play_sound complete
    PREVIEW="${TRIMMED_TEXT:0:100}"
    if [ ${#TRIMMED_TEXT} -gt 100 ]; then
        PREVIEW="${PREVIEW}..."
    fi
    notify-send --app-name "OCR" -t 5000 "OCR" -i "ocrfeeder" "Text copied to clipboard:\n$PREVIEW"
else
    play_sound dialog-warning
    notify-send --app-name "OCR" -t 5000 "OCR" -i "dialog-warning" "No text recognized."
fi
