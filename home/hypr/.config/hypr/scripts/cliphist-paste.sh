#!/usr/bin/env bash
set -euo pipefail

preview="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/cliphist-preview.sh"
runner=$(mktemp)
trap 'rm -f "$runner"' EXIT

if [[ -f "$HOME/.cache/theme-mode" ]] && [[ "$(cat "$HOME/.cache/theme-mode")" == "light" ]]; then
    fzf_theme="bg+:#e1e2e7,bg:#eff1f5,fg:#3760bf,hl:#2e7de9,fg+:#3760bf,hl+:#2e7de9,header:#2e7de9,info:#2e7de9,pointer:#2e7de9,marker:#2e7de9,prompt:#2e7de9,spinner:#2e7de9"
else
    fzf_theme="bg+:#2f334d,bg:#222436,fg:#c8d3f5,hl:#2ccade,fg+:#c8d3f5,hl+:#2ccade,header:#2ccade,info:#2ccade,pointer:#2ccade,marker:#2ccade,prompt:#2ccade,spinner:#2ccade"
fi

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
    wtype -M ctrl V -m ctrl
fi
SCRIPT

chmod +x "$runner"
ghostty --title=Clipboard -e "$runner"
