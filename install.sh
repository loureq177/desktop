#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then
    echo "Detected Linux. Applying Archlinux configs..."
    chmod +x archlinux/bin/.local/bin/*
    (cd archlinux && stow --restow --target ~ */)
fi

if [ "$OS" = "Darwin" ]; then
    echo "Detected macOS. Applying macOS configs..."
    chmod +x macos/bin/.local/bin/* 2>/dev/null || true
    (cd macos && stow --restow --target ~ */)
fi

echo "Applying common configs..."
(cd common && stow --restow --target ~ */)

if command -v bat &>/dev/null; then
    echo "Building bat cache for custom themes..."
    bat cache --build >/dev/null 2>&1
    echo "Bat cache rebuilt."
fi
echo "Done."
