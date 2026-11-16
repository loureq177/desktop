#!/bin/sh
# With /var/lib/dgpu/mode "off" (written by `dgpu`) this boot has no NVIDIA GPU: its
# modules never load and the unbound card sleeps in D3cold until the next boot with it.
[ "$(cat /var/lib/dgpu/mode 2>/dev/null)" = off ] || exit 0
mkdir -p /run/modprobe.d
for module in nvidia nvidia_modeset nvidia_drm nvidia_uvm; do
    echo "install $module /bin/true"
done >/run/modprobe.d/dgpu-off.conf
for dev in /sys/bus/pci/devices/*; do
    [ "$(cat "$dev/vendor")" = 0x10de ] && echo auto >"$dev/power/control"
done
exit 0
