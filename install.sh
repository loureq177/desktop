#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v stow &>/dev/null; then
    echo "Error: GNU Stow is not installed."
    exit 1
fi

mkdir -p ~/.config ~/.local/share ~/.local/state ~/.local/bin ~/.cache

OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then
    echo "Detected Linux. Applying Archlinux configs..."
    if [ -d "archlinux/bin/.local/bin" ]; then
        chmod +x archlinux/bin/.local/bin/* 2>/dev/null || true
    fi
    (cd archlinux && stow --restow --target ~ */)
fi

if [ "$OS" = "Darwin" ]; then
    echo "Detected macOS. Applying macOS configs..."
    if [ -d "macos/bin/.local/bin" ]; then
        chmod +x macos/bin/.local/bin/* 2>/dev/null || true
    fi
    if [ -d "macos" ]; then
        (cd macos && stow --restow --target ~ */)
    fi
fi

echo "Applying common configs..."
(cd common && stow --restow --target ~ */)

if command -v bat &>/dev/null; then
    echo "Building bat cache for custom themes..."
    bat cache --build >/dev/null 2>&1
    echo "Bat cache rebuilt."
fi

if command -v hyprpm &>/dev/null; then
    echo "Setting up Hyprland plugins..."
    sudo hyprpm add https://github.com/KZDKM/Hyprspace 2>/dev/null || true
    sudo hyprpm enable Hyprspace 2>/dev/null || true
fi

echo "Done."
