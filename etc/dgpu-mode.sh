#!/bin/sh
# With /var/lib/dgpu/mode "off" (written by `dgpu`) this boot has no NVIDIA GPU: the card
# leaves the PCI bus, so no driver loads for it and it sleeps until the next boot with it.
[ "$(cat /var/lib/dgpu/mode 2>/dev/null)" = off ] || exit 0
mkdir -p /run/modprobe.d
for module in nvidia nvidia_modeset nvidia_drm nvidia_uvm; do
    echo "install $module /bin/true"
done >/run/modprobe.d/dgpu-off.conf
# Removed, not just denied in modprobe.d: kmod ignores `install` for nvidia (it has softdeps),
# and udev loads it through nvidia_drm's PCI alias; nvidia-modprobe skips a GPU-less bus.
for dev in /sys/bus/pci/devices/*; do
    [ "$(cat "$dev/vendor" 2>/dev/null)" = 0x10de ] && echo 1 >"$dev/remove"
done
exit 0
