#!/usr/bin/env bash
set -euo pipefail

preview="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/cliphist-preview.sh"
runner=$(mktemp)
status_file=$(mktemp)
trap 'rm -f "$runner" "$status_file"' EXIT

fzf_theme="bg+:#2f334d,bg:#222436,fg:#c8d3f5,hl:#2ccade,fg+:#c8d3f5,hl+:#2ccade,header:#2ccade,info:#2ccade,pointer:#2ccade,marker:#2ccade,prompt:#2ccade,spinner:#2ccade"

cat >"$runner" <<SCRIPT
#!/bin/bash
tab=\$(printf '\t')
selected=\$(cliphist list | fzf \
  --delimiter="\$tab" \
  --with-nth=2.. \
  --nth=2.. \
  --preview="$preview {1}" \
  --preview-window='right:60%' \
  --prompt='Clipboard > ' \
  --border \
  --info=inline \
  --color='$fzf_theme')

if [[ -n "\$selected" ]]; then
    id=\$(echo "\$selected" | cut -f1)
    cliphist decode "\$id" | wl-copy
    echo "selected" > "$status_file"
fi
SCRIPT

chmod +x "$runner"
ghostty --class=clipboard-special --title=Clipboard -e "$runner"

# After ghostty closes, check if we selected something and paste it
if [[ -s "$status_file" ]]; then
    sleep 0.25
    wtype -M ctrl -k v -m ctrl
fi
