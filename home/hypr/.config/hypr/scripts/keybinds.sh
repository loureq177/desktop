#!/usr/bin/env bash
# Show Hyprland keybindings in rofi
set -euo pipefail

LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf/keybindings.lua"
TEMA="$HOME/.config/rofi/theme-keybinds.rasi"
[[ ! -f "$LUA" ]] && exit 1

describe() {
  local a="$1"
  [[ "$a" =~ programs\.special\.([a-z]+) ]] && { echo "Toggle ${BASH_REMATCH[1]}"; return; }
  case "$a" in
    *terminal*)     echo "Open terminal";;       *launcher*)  echo "Open app launcher";;
    *runner*)       echo "Open command runner";;  *powermenu*) echo "Power menu";;
    *cliphist*)     echo "Clipboard history";;   *keybinds*)  echo "Show keybindings";;
    *screenshot*region*) echo "Screenshot region";;  *screenshot*full*) echo "Screenshot full";;
    *hyprlock*)     echo "Lock screen";;         *hyprpicker*) echo "Color picker";;
    *window.close*) echo "Close window";;         *fullscreen*) echo "Toggle fullscreen";;
    *float*)        echo "Toggle float";;         *pseudo*)    echo "Toggle pseudo";;
    *swap*)         echo "Swap window";;          *window.move*) echo "Move to workspace";;
    *focus*direction*) echo "Focus direction";;   *focus*workspace*) echo "Switch workspace";;
    *layout*)       echo "Toggle split";;         *Escape*)    echo "Close special workspace";;
    *Tab*)          echo "Cycle windows";;        *rofi*)      echo "Launch app";;
    *wpctl*)        echo "Volume / audio";;       *brightness*) echo "Brightness";;
    *playerctl*)    echo "Media control";;        *browser*)   echo "Open / focus browser";;
    *cycle_next*)   echo "Cycle windows";;        *toggle_special*) echo "Toggle special workspace";;
  esac
}

process() {
  local line="$1" key action desc
  line="${line//$'\n'/ }"; line="$(printf '%s' "$line" | tr -s ' ')"
  [[ "$line" != *"hl.bind("* ]] && return
  [[ "$line" == *"mouse:"* || "$line" == *"switch:"* ]] && return

  local rest="${line#*hl.bind(}"
  rest="${rest%)}"

  key="${rest%%,*}"
  key="${key//mod \.\. /SUPER}"
  key="${key//\"/}"; key="${key// \.\. / }"
  key="$(printf '%s' "$key" | xargs)"

  action="${rest#*,}"

  if [[ "$action" == *"function("* ]]; then
    case "$key" in *Escape*) desc="Close special workspace";; *Tab*) desc="Cycle windows";; *B) desc="Open / focus browser";; esac
  else
    desc=$(describe "$action")
  fi
  [[ -n "$desc" ]] && printf "%s\t%s\n" "$desc" "$key"
}

{
  for i in {1..10}; do
    printf "Switch to workspace %d\tSUPER + %d\n" "$i" "$((i % 10))"
    printf "Move to workspace %d\tSUPER + SHIFT + %d\n" "$i" "$((i % 10))"
  done

  acc=""; depth=0
  while IFS= read -r line; do
    [[ "$line" == "for "* ]] && { while IFS= read -r l; do [[ "$l" == "end" ]] && break; done; continue; }

    if [[ -n "$acc" ]]; then
      acc+=$'\n'"$line"
      for ((k=0; k<${#line}; k++)); do
        c="${line:k:1}"; [[ "$c" == "(" ]] && ((depth++)); [[ "$c" == ")" ]] && ((depth--))
      done
      ((depth == 0)) && { process "$acc"; acc=""; depth=0; }
      continue
    fi

    [[ "$line" != *"hl.bind("* ]] && continue
    [[ "$line" == *"mouse:"* || "$line" == *"switch:"* ]] && continue

    d=0
    for ((k=0; k<${#line}; k++)); do
      c="${line:k:1}"; [[ "$c" == "(" ]] && ((d++)); [[ "$c" == ")" ]] && ((d--))
    done
    if ((d > 0)); then acc="$line"; depth=$d; else process "$line"; fi
  done < "$LUA"
} | sort -f | while IFS=$'\t' read -r desc key; do
  printf "%-28s %s\n" "$desc" "$key"
done | rofi -dmenu -i -p " Keybinds " -theme "$TEMA"
