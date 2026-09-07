#!/usr/bin/env bash
# Clipboard history picker: opens fzf preview (chafa/bat) in Ghostty, copies and pastes via wtype.
set -euo pipefail

# Source centralized UI variables if available
UI_SH="${XDG_CONFIG_HOME:-$HOME/.config}/ui/ui.sh"
if [[ -f "$UI_SH" ]]; then
    # shellcheck source=/dev/null
    source "$UI_SH"
fi

fzf_theme="${UI_FZF_THEME:-bg+:#21262d,bg:#0d1117,fg:#c9d1d9,hl:#58a6ff,fg+:#c9d1d9,hl+:#58a6ff,header:#58a6ff,info:#8b949e,pointer:#58a6ff,marker:#3fb950,prompt:#58a6ff,spinner:#58a6ff,border:#30363d}"

status_file=$(mktemp)
trap 'rm -f "$status_file"' EXIT

ghostty --class=clipboard-special -e bash -c "
tab=\$(printf '\t')
selected=\$(cliphist list | fzf \
  --delimiter=\"\$tab\" \
  --with-nth=2.. \
  --nth=2.. \
  --preview=\"entry_id={1}; mime=\\\$(cliphist decode \\\"\\\$entry_id\\\" | head -c 2048 | file -b --mime-type -); printf '\\e_Ga=d\\e\\\\'; if [[ \\\"\\\$mime\\\" == image/* ]]; then cliphist decode \\\"\\\$entry_id\\\" | chafa --fill=block --symbols=block --colors=256 --size=\\\${FZF_PREVIEW_COLUMNS}x\\\${FZF_PREVIEW_LINES} -; else cliphist decode \\\"\\\$entry_id\\\" | bat --paging=never --style=plain --color=always; fi\" \
  --preview-window='right:60%' \
  --prompt='Clipboard > ' \
  --border \
  --info=inline \
  --color=\"$fzf_theme\")

if [[ -n \"\$selected\" ]]; then
    id=\$(printf '%s\n' \"\$selected\" | cut -f1)
    cliphist decode \"\$id\" | wl-copy
    echo 1 > \"$status_file\"
fi
"

if [[ -s "$status_file" ]]; then
    sleep 0.25
    wtype -M ctrl -k v -m ctrl
fi
