#!/usr/bin/env bash
# Build newest stable kernel (x86_64 defconfig + KVM guest bits) and boot it in QEMU with a tiny initramfs.
set -euo pipefail
cd "$(dirname "$0")/.."
VER=${KERNEL_VERSION:-$(PYTHONPATH=zeros_py python3 -c 'from zeros import kernel;print(kernel.latest_stable())')}
echo "Kernel under test: $VER"
W=${WORK:-/tmp/kboot}; mkdir -p "$W"; cd "$W"
[ -f "linux-$VER.tar.xz" ] || curl -fsSLO "https://cdn.kernel.org/pub/linux/kernel/v${VER%%.*}.x/linux-$VER.tar.xz"
[ -d "linux-$VER" ] || tar xf "linux-$VER.tar.xz"
cd "linux-$VER"
make x86_64_defconfig >/dev/null
scripts/config -e KVM_GUEST -e SERIAL_8250_CONSOLE -e BTRFS_FS -e DEVTMPFS -e DEVTMPFS_MOUNT -e BLK_DEV_INITRD
make olddefconfig >/dev/null
make -j"$(nproc)" bzImage >/dev/null
mkdir -p "$W/rd/bin" && cp "$(command -v busybox)" "$W/rd/bin/busybox"
cat > "$W/rd/init" <<'INIT'
#!/bin/busybox sh
/bin/busybox mount -t proc none /proc
echo "ZEROS_BOOT_OK kernel=$(/bin/busybox uname -r)"
/bin/busybox poweroff -f
INIT
chmod +x "$W/rd/init"
(cd "$W/rd" && find . | cpio -o -H newc --quiet | gzip > "$W/initrd.gz")
timeout 120 qemu-system-x86_64 -m 512 -nographic -no-reboot \
  -kernel arch/x86/boot/bzImage -initrd "$W/initrd.gz" \
  -append "console=ttyS0 panic=1" | tee "$W/boot.log" || true
grep -q ZEROS_BOOT_OK "$W/boot.log" && echo "PASS: kernel $VER boots" || { echo "FAIL"; exit 1; }
