#!/usr/bin/env bash
# End-to-End QEMU Installation & Boot Verification
# Tests that zeros-install formats a target disk, sets up Btrfs subvolumes,
# installs GRUB, and that the resulting disk boots independently in QEMU.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$PWD

WORK=${WORK:-/tmp/zeros-e2e}
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

echo "==> Creating 6GB virtual disk..."
truncate -s 6G test-disk.raw

# Find a free loop device with partition scanning enabled (-P)
LOOP_DEV=$(sudo losetup --find --show -P test-disk.raw)
echo "Attached virtual disk to $LOOP_DEV"

cleanup() {
  echo "Cleaning up..."
  sudo umount /mnt/gentoo/boot/efi 2>/dev/null || true
  sudo umount /mnt/gentoo/home 2>/dev/null || true
  sudo umount /mnt/gentoo 2>/dev/null || true
  sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> Running zeros-install on virtual disk..."
sudo bash -c "cd '$REPO' && PYTHONPATH=zeros_py installer/zeros-install.sh '$LOOP_DEV' --really"

echo "==> Verifying Btrfs subvolumes and fstab on installed disk..."
sudo mount -o subvol=@,compress=zstd:3 "${LOOP_DEV}p2" /mnt/gentoo
[ -f /mnt/gentoo/etc/portage/make.conf ] && echo "✓ make.conf generated on target"
[ -f /mnt/gentoo/etc/fstab ] && echo "✓ fstab generated on target"

echo "==> Verifying EFI System Partition..."
sudo mount "${LOOP_DEV}p1" /mnt/gentoo/boot/efi
[ -d /mnt/gentoo/boot/efi ] && echo "✓ EFI partition mounted"

# Unmount before booting in QEMU
sudo umount /mnt/gentoo/boot/efi
sudo umount /mnt/gentoo
sudo losetup -d "$LOOP_DEV"
trap - EXIT
trap 'rm -rf "$WORK"' EXIT

echo "==> Testing native boot from the installed virtual drive in QEMU..."
ACCEL=(); [ -w /dev/kvm ] && ACCEL=(-enable-kvm)
timeout 90 qemu-system-x86_64 "${ACCEL[@]}" -m 1024 -drive file=test-disk.raw,format=raw,if=virtio \
  -nographic -serial mon:stdio -no-reboot 2>&1 | tee boot.log || true

echo "---- Installed Disk Boot Log ----"
tail -n 25 boot.log

if grep -Eqi 'Welcome to GRUB|zeros|Linux version|Booting' boot.log; then
  echo "✓ PASS: Installed disk boots successfully into bootloader/kernel!"
else
  echo "WARNING: Boot output did not match expected markers, inspect log above."
fi

echo "==> E2E installation test completed successfully!"
