#!/usr/bin/env bash
set -euo pipefail

entry_id="$1"
mime=$(set +o pipefail; cliphist decode "$entry_id" | head -c 2048 | file -b --mime-type -)

printf '\e_Ga=d\e\\'

if [[ "$mime" == image/* ]]; then
    cliphist decode "$entry_id" | chafa --fill=block --symbols=block --colors=256 --size=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES} -
else
    cliphist decode "$entry_id" | bat --paging=never --style=plain --color=always
fi
