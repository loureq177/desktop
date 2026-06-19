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
    (cd archlinux && stow --verbose --restow --target ~ */)

    if [ -f "archlinux/speech-to-text/.local/bin/dictate-setup" ]; then
        echo "Setting up Speech-to-Text (Dictate)..."
        bash archlinux/speech-to-text/.local/bin/dictate-setup
    fi
fi

if [ "$OS" = "Darwin" ]; then
    echo "Detected macOS. Applying macOS configs..."
    if [ -d "macos/bin/.local/bin" ]; then
        chmod +x macos/bin/.local/bin/* 2>/dev/null || true
    fi
    if [ -d "macos" ]; then
        (cd macos && stow --verbose --restow --target ~ */)
    fi
fi

echo "Applying common configs..."
(cd common && stow --verbose --restow --target ~ */)

if command -v bat &>/dev/null; then
    echo "Building bat cache for custom themes..."
    bat cache --build >/dev/null 2>&1
    echo "Bat cache rebuilt."
fi

if command -v systemctl &>/dev/null; then
    echo "Enabling user services..."
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now dictate-daemon.service 2>/dev/null || true
fi

echo "Done."
