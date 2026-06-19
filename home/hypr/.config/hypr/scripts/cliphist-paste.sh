#!/usr/bin/env bash
set -euo pipefail

preview="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/cliphist-preview.sh"
runner=$(mktemp)

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
  --color='bg+:#2f334d,bg:#222436,fg:#c8d3f5,hl:#2ccade,fg+:#c8d3f5,hl+:#2ccade,header:#2ccade,info:#2ccade,pointer:#2ccade,marker:#2ccade,prompt:#2ccade,spinner:#2ccade')

if [[ -n "\$selected" ]]; then
    id=\$(echo "\$selected" | cut -f1)
    cliphist decode "\$id" | wl-copy
    wtype -M ctrl V -m ctrl
fi
SCRIPT

chmod +x "$runner"
ghostty --title=Clipboard -e "$runner"
rm -f "$runner"
