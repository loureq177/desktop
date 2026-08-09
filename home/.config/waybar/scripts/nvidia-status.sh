#!/usr/bin/env bash
set -euo pipefail

PCI_DEV_CACHE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nvidia_pci_dev"
if [ ! -f "$PCI_DEV_CACHE" ]; then
    nvidia_vendor=$(grep -lx "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null | head -1 || true)
    if [ -n "$nvidia_vendor" ]; then
        dirname "$nvidia_vendor" > "$PCI_DEV_CACHE"
    else
        echo "none" > "$PCI_DEV_CACHE"
    fi
fi

pci_dev=$(cat "$PCI_DEV_CACHE")
if [ "$pci_dev" = "none" ]; then
    echo '{"text":"󰢮","class":"none","tooltip":"No NVIDIA GPU found"}'
    exit 0
fi

status=$(cat "$pci_dev/power/runtime_status" 2>/dev/null)

case "$status" in
    suspended)
        echo '{"text":"󰢮","class":"off","tooltip":"dGPU: suspended"}'
        ;;
    active)
        echo '{"text":"󰢮","class":"on","tooltip":"dGPU: active"}'
        ;;
    *)
        echo '{"text":"󰢮","class":"unknown","tooltip":"dGPU: unknown ('"$status"')"}'
        ;;
esac
