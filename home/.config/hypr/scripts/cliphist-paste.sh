#!/usr/bin/env bash
set -euo pipefail

fzf_theme="bg+:#2f334d,bg:#222436,fg:#c8d3f5,hl:#2ccade,fg+:#c8d3f5,hl+:#2ccade,header:#2ccade,info:#2ccade,pointer:#2ccade,marker:#2ccade,prompt:#2ccade,spinner:#2ccade"

status_file=$(mktemp)
trap 'rm -f "$status_file"' EXIT

ghostty --class=clipboard-special --title=Clipboard -e bash -c "
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
