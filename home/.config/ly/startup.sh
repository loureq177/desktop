#!/bin/sh
set -eu
if [ "${TERM:-linux}" = "linux" ]; then
    printf '\033]P00d1117'
    printf '\033]P1f85149'
    printf '\033]P23fb950'
    printf '\033]P3d29922'
    printf '\033]P41f6feb'
    printf '\033]P58957e5'
    printf '\033]P658a6ff'
    printf '\033]P7c9d1d9'
    printf '\033]P830363d'
    printf '\033]P9f85149'
    printf '\033]PA3fb950'
    printf '\033]PBd29922'
    printf '\033]PC58a6ff'
    printf '\033]PDbc8cff'
    printf '\033]PE79c0ff'
    printf '\033]PFf0f6fc'
    clear
fi
