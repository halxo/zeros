#!/usr/bin/env bash
# Structural + QEMU smoke test of a built ISO. Usage: iso-verify.sh path.iso
set -euo pipefail
ISO=$1
xorriso -indev "$ISO" -report_el_torito plain 2>&1 | grep -qi 'El Torito' && echo "boot record present"
xorriso -indev "$ISO" -ls / 2>&1 | grep -q image.squashfs && echo "squashfs present"
unsquashfs -ls <(true) >/dev/null 2>&1 || true
xorriso -osirrox on -indev "$ISO" -extract /image.squashfs /tmp/v.squashfs >/dev/null 2>&1
unsquashfs -l /tmp/v.squashfs | grep -q 'usr/local/bin/zeros-install' && echo "zeros-install injected"
unsquashfs -l /tmp/v.squashfs | grep -q 'usr/share/zeros-overlay' && echo "overlay injected"
# boot smoke: BIOS boot reaches the bootloader (isolinux banner) in QEMU
timeout 60 qemu-system-x86_64 -m 2048 -cdrom "$ISO" -boot d -nographic -serial mon:stdio -no-reboot 2>&1 | tee /tmp/isoboot.log | head -c 4000 || true
grep -Eqi 'isolinux|syslinux|gentoo|boot:|grub' /tmp/isoboot.log && echo "PASS: ISO bootloader reached" || { echo "FAIL: no bootloader output"; exit 1; }
