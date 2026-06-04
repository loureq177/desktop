#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chmod +x common/bin/.local/bin/*

echo "Applying common configs..."
cd common && stow --restow --target ~ */ && cd ..

echo "Applying archlinux configs..."
cd archlinux && stow --restow --target ~ */ && cd ..

echo "Done."
