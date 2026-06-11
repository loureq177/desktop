#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chmod +x common/bin/.local/bin/*

echo "Applying common configs..."
cd common && stow --restow --target ~ */ && cd ..

echo "Applying archlinux configs..."
cd archlinux && stow --restow --target ~ */ && cd ..

if command -v bat &>/dev/null; then
    _log_info "Building bat cache for custom themes..."
    bat cache --build >/dev/null 2>&1 || _log_warn "Failed to build bat cache."
    _log_ok "Bat cache rebuilt."
fi

echo "Done."
