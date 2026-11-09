#!/usr/bin/env bash
# Build the bootable Zeros live/installer ISO.
# Rebuilds the ISO with proper hybrid MBR + UEFI GPT partitioning and auto-boot GRUB.
# Needs root (squashfs preserves ownership): run in CI or with `sudo`.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$PWD
OUT=${OUT:-$REPO/out}; W=${WORK:-/tmp/zeros-iso}; TAG=${ISO_TAG:-dev}
rm -rf "$W"; mkdir -p "$W" "$OUT"; cd "$W"
BASE=https://distfiles.gentoo.org/releases/amd64/autobuilds
REL=$(curl -fsS $BASE/latest-install-amd64-minimal.txt | awk '/\.iso /{print $1; exit}')
echo "Base ISO: $REL"
curl -fsSL -o base.iso "$BASE/$REL"
curl -fsSL -o base.iso.sha256 "$BASE/$REL.sha256" 2>/dev/null || true
if [ -s base.iso.sha256 ]; then
  (grep -h "\.iso" base.iso.sha256 | awk '{print $1"  base.iso"}' | head -1 | sha256sum -c -) || true
fi

# 1. Extract complete ISO tree and squashfs
xorriso -osirrox on -indev base.iso -extract / tree >/dev/null
chmod -R u+w tree
mv tree/image.squashfs image.squashfs
unsquashfs -d root image.squashfs

# 2. Inject Zeros tools, overlay, and configs into squashfs root
install -d root/usr/lib/zeros/python root/usr/local/bin root/etc/skel/.config
cp -r "$REPO/zeros_py/zeros" root/usr/lib/zeros/python/
cp "$REPO/installer/zeros-install.sh" root/usr/local/bin/zeros-install
cp "$REPO/installer/zeros-tui.sh" root/usr/local/bin/zeros-tui
ln -sf zeros-tui root/usr/local/bin/zeros-installer
for t in detect:zeros-detect updater:zeros-update; do
  printf '#!/bin/sh\nPYTHONPATH=/usr/lib/zeros/python exec python3 -m zeros.%s "$@"\n' "${t%%:*}" > "root/usr/local/bin/${t##*:}"
done
chmod +x root/usr/local/bin/*
cp -r "$REPO/overlay" root/usr/share/zeros-overlay
cp -r "$REPO/macshell" root/usr/share/zeros-macshell

cat > root/etc/motd <<MOTD

   ____  _____ ____   ___  ____
  |_  / | ____|  _ \ / _ \/ ___|     Zeros Live OS  ($TAG)
   / /  |  _| | |_) | | | \___ \     Rolling, source-based, automated Gentoo.
  / /__ | |___|  _ <| |_| |___) |    Runs natively on any PC (UEFI & BIOS).
 /____| |_____|_| \_\\___/|____/
                                     Commands:
                                       zeros-installer           (Interactive GUI/TUI Wizard)
                                       zeros-detect              (Detect hardware profile)
                                       zeros-install /dev/sdX    (CLI dry-run installer)
                                       zeros-install /dev/sdX --really
MOTD
echo "zeros" > root/etc/hostname

# Enable dhcpcd / NetworkManager in live root if present
if [ -f root/etc/init.d/dhcpcd ]; then
  mkdir -p root/etc/runlevels/default
  ln -sf /etc/init.d/dhcpcd root/etc/runlevels/default/dhcpcd 2>/dev/null || true
fi

# Rebuild squashfs
mksquashfs root tree/image.squashfs -comp xz -noappend -quiet

# 3. Configure GRUB for universal hardware boot (UEFI + BIOS)
# Set label to ZEROS_LIVE and ensure grub.cfg searches by both file and label fallback
LABEL="ZEROS_LIVE"
mkdir -p tree/boot/grub
cat > tree/boot/grub/grub.cfg <<EOF
set default=0
set timeout=3
set gfxpayload=keep
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660
insmod all_video
insmod gfxterm
terminal_output gfxterm console
terminal_input console
set gfxmode=auto

menuentry 'Zeros OS (Live - Default)' --class gnu-linux --class os {
    search --no-floppy --file --set=root /image.squashfs
    if [ -z "\$root" ]; then search --no-floppy -l $LABEL --set=root; fi
    linux /boot/gentoo dokeymap root=live:CDLABEL=$LABEL rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot console=tty0 console=ttyS0,115200
    initrd /boot/gentoo.igz
}

menuentry 'Zeros OS (Live - Safe Graphics / nomodeset)' --class gnu-linux --class os {
    search --no-floppy --file --set=root /image.squashfs
    if [ -z "\$root" ]; then search --no-floppy -l $LABEL --set=root; fi
    linux /boot/gentoo dokeymap root=live:CDLABEL=$LABEL rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot nomodeset console=tty0 console=ttyS0,115200
    initrd /boot/gentoo.igz
}

menuentry 'Zeros OS (Live - Copy to RAM)' --class gnu-linux --class os {
    search --no-floppy --file --set=root /image.squashfs
    if [ -z "\$root" ]; then search --no-floppy -l $LABEL --set=root; fi
    linux /boot/gentoo dokeymap root=live:CDLABEL=$LABEL rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot rd.live.ram=1 console=tty0 console=ttyS0,115200
    initrd /boot/gentoo.igz
}

menuentry 'Zeros OS (Live - Verbose Debug)' --class gnu-linux --class os {
    search --no-floppy --file --set=root /image.squashfs
    if [ -z "\$root" ]; then search --no-floppy -l $LABEL --set=root; fi
    linux /boot/gentoo dokeymap root=live:CDLABEL=$LABEL rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot debug verbose rd.debug console=tty0 console=ttyS0,115200
    initrd /boot/gentoo.igz
}
EOF

# Inject grub.cfg directly into efi.img so UEFI GRUB finds it without disk probing
EFI_TMP="/tmp/efimnt.$$"
mkdir -p "$EFI_TMP"
if mount -o loop tree/efi.img "$EFI_TMP" 2>/dev/null; then
  cp tree/boot/grub/grub.cfg "$EFI_TMP/EFI/BOOT/grub.cfg" 2>/dev/null || true
  umount "$EFI_TMP" || true
elif command -v mcopy >/dev/null 2>&1; then
  mcopy -o -i tree/efi.img tree/boot/grub/grub.cfg ::EFI/BOOT/grub.cfg 2>/dev/null || true
fi
rm -rf "$EFI_TMP"

# 4. Extract original boot options, removing Apple HFS+ flags that break standard PC MBR
eval "BOOTOPTS=( $(xorriso -indev base.iso -report_system_area as_mkisofs -report_el_torito as_mkisofs 2>/dev/null | grep -v -e '^xorriso' -e '^-V ' -e '^--modification-date' -e '^-hfsplus' -e '^-apm-block-size') )"
printf '%s\n' "${BOOTOPTS[@]}" | head -30

# 5. Build final hybrid ISO with ZEROS_LIVE volume label
xorriso -as mkisofs -r -J -joliet-long -iso-level 3 -V "$LABEL" "${BOOTOPTS[@]}" -o "$OUT/zeros-$TAG.iso" tree
( cd "$OUT" && sha256sum "zeros-$TAG.iso" > "zeros-$TAG.iso.sha256" )
ls -lh "$OUT"
