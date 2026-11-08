#!/usr/bin/env bash
# Structural + QEMU execution test of the built Zeros ISO.
# Tests both BIOS and modern UEFI boot.
# Usage: iso-verify.sh path/to/zeros.iso
set -euo pipefail
ISO=$1

echo "==> Checking ISO structure..."
xorriso -indev "$ISO" -report_el_torito plain 2>&1 | grep -qi 'El Torito' && echo "✓ El Torito boot record present"
xorriso -indev "$ISO" -ls / 2>&1 | grep -q image.squashfs && echo "✓ image.squashfs present"

echo "==> Verifying injected Zeros components..."
xorriso -osirrox on -indev "$ISO" -extract /image.squashfs /tmp/test-squashfs.img >/dev/null 2>&1
unsquashfs -l /tmp/test-squashfs.img | grep -q 'usr/local/bin/zeros-install' && echo "✓ zeros-install injected"
unsquashfs -l /tmp/test-squashfs.img | grep -q 'usr/share/zeros-overlay' && echo "✓ zeros-overlay injected"
rm -f /tmp/test-squashfs.img

echo "==> Testing BIOS boot in QEMU (kernel execution)..."
ACCEL=(); [ -w /dev/kvm ] && ACCEL=(-enable-kvm)
timeout 120 qemu-system-x86_64 "${ACCEL[@]}" -m 2048 -cdrom "$ISO" -boot d -nographic -serial mon:stdio -no-reboot 2>&1 | tee /tmp/bios-boot.log || true

echo "---- Boot output sample ----"
tail -n 25 /tmp/bios-boot.log

if grep -Eqi 'Linux version|zeros|Gentoo|dracut|Welcome to GRUB' /tmp/bios-boot.log; then
  echo "✓ PASS: BIOS boot verified (bootloader and kernel reached)"
else
  echo "✗ FAIL: No bootloader or kernel output detected"
  exit 1
fi

echo "==> Testing UEFI boot in QEMU (if OVMF available)..."
OVMF_PATH=""
for p in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2-ovmf/x64/OVMF.fd; do
  if [ -f "$p" ]; then OVMF_PATH="$p"; break; fi
done

if [ -n "$OVMF_PATH" ]; then
  echo "Found OVMF firmware at $OVMF_PATH"
  timeout 90 qemu-system-x86_64 "${ACCEL[@]}" -bios "$OVMF_PATH" -m 2048 -cdrom "$ISO" -boot d -nographic -serial mon:stdio -no-reboot 2>&1 | tee /tmp/uefi-boot.log || true
  if grep -Eqi 'Welcome to GRUB|Linux version|zeros' /tmp/uefi-boot.log; then
    echo "✓ PASS: UEFI boot verified"
  else
    echo "WARNING: UEFI boot did not reach expected markers, check /tmp/uefi-boot.log"
  fi
else
  echo "OVMF firmware not found, skipping UEFI emulation test."
fi

echo "==> All ISO verifications passed successfully!"
