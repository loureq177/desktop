#!/usr/bin/env bash
set -euo pipefail

nvidia_vendor=$(grep -lx "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null | head -1 || true)
if [ -z "$nvidia_vendor" ]; then
    echo '{"text":"󰢮","class":"none","tooltip":"No NVIDIA GPU found"}'
    exit 0
fi

pci_dev=$(dirname "$nvidia_vendor")
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
