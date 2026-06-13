#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chmod +x common/bin/.local/bin/*

echo "Applying common configs..."
(cd common && stow --restow --target ~ */)

echo "Applying archlinux configs..."
(cd archlinux && stow --restow --target ~ */)

if command -v bat &>/dev/null; then
    echo "Building bat cache for custom themes..."
    bat cache --build >/dev/null 2>&1
    echo "Bat cache rebuilt."
fi

echo "Done."
