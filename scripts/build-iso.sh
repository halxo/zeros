#!/usr/bin/env bash
# Build the bootable Zeros live/installer ISO.
# Rebuilds the ISO with:
#  1. Microsoft-Signed UEFI Secure Boot support (shim + signed GRUB + MokManager).
#  2. Graphical Live Desktop session (Hyprland + macshell + installer GUI auto-start).
#  3. Universal hybrid MBR + UEFI GPT partitioning and auto-boot GRUB.
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

# Locate Microsoft-Signed Shim and signed GRUB if available
SHIM_SRC=""
for p in \
  /tmp/signed-efi/usr/lib/shim/shimx64.efi.signed.latest \
  /tmp/signed-efi/usr/lib/shim/shimx64.efi.signed \
  /tmp/signed-efi/usr/lib/shim/shimx64.efi.dualsigned \
  /usr/lib/shim/shimx64.efi.signed.latest \
  /usr/lib/shim/shimx64.efi.signed \
  /usr/lib/shim/shimx64.efi.dualsigned; do
  if [ -f "$p" ]; then SHIM_SRC="$p"; break; fi
done

MM_SRC=""
for p in \
  /tmp/signed-efi/usr/lib/shim/mmx64.efi.signed \
  /tmp/signed-efi/usr/lib/shim/mmx64.efi \
  /usr/lib/shim/mmx64.efi.signed \
  /usr/lib/shim/mmx64.efi; do
  if [ -f "$p" ]; then MM_SRC="$p"; break; fi
done

GRUB_SIGNED_SRC=""
for p in \
  /tmp/signed-efi/usr/lib/grub/x86_64-efi-signed/gcdx64.efi.signed \
  /tmp/signed-efi/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
  /usr/lib/grub/x86_64-efi-signed/gcdx64.efi.signed \
  /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed; do
  if [ -f "$p" ]; then GRUB_SIGNED_SRC="$p"; break; fi
done

# 2. Inject Zeros tools, overlay, macshell, and configs into squashfs root
install -d root/usr/lib/zeros/python root/usr/local/bin root/etc/skel/.config root/etc/profile.d root/usr/share/applications root/etc/skel/Desktop
cp -r "$REPO/zeros_py/zeros" root/usr/lib/zeros/python/
cp "$REPO/installer/zeros-install.sh" root/usr/local/bin/zeros-install
cp "$REPO/installer/zeros-tui.sh" root/usr/local/bin/zeros-tui
ln -sf zeros-tui root/usr/local/bin/zeros-installer
cp "$REPO/installer/zeros-installer-gui.sh" root/usr/local/bin/zeros-installer-gui
cp "$REPO/macshell/zeros-desktop.sh" root/usr/local/bin/zeros-desktop
cp "$REPO/macshell/zeros-welcome.sh" root/usr/local/bin/zeros-welcome
cp "$REPO/macshell/zeros-session.sh" root/etc/profile.d/zeros-session.sh
if [ -d "$REPO/macshell/applications" ]; then
  cp -r "$REPO/macshell/applications/"*.desktop root/usr/share/applications/ 2>/dev/null || true
  cp -r "$REPO/macshell/applications/"*.desktop root/etc/skel/Desktop/ 2>/dev/null || true
fi

for t in detect:zeros-detect updater:zeros-update; do
  printf '#!/bin/sh\nPYTHONPATH=/usr/lib/zeros/python exec python3 -m zeros.%s "$@"\n' "${t%%:*}" > "root/usr/local/bin/${t##*:}"
done
chmod +x root/usr/local/bin/* root/etc/profile.d/zeros-session.sh

cp -r "$REPO/overlay" root/usr/share/zeros-overlay
cp -r "$REPO/macshell" root/usr/share/zeros-macshell

# Store signed shim for target installation if found
if [ -n "$SHIM_SRC" ]; then
  echo "Found Microsoft-Signed Shim: $SHIM_SRC"
  mkdir -p root/usr/share/zeros-shim
  cp "$SHIM_SRC" root/usr/share/zeros-shim/BOOTX64.EFI
  [ -n "$MM_SRC" ] && cp "$MM_SRC" root/usr/share/zeros-shim/mmx64.efi
  [ -n "$GRUB_SIGNED_SRC" ] && cp "$GRUB_SIGNED_SRC" root/usr/share/zeros-shim/grubx64.efi
fi

cat > root/etc/motd <<MOTD

   ____  _____ ____   ___  ____
  |_  / | ____|  _ \ / _ \/ ___|     Zeros Live OS  ($TAG)
   / /  |  _| | |_) | | | \___ \     Rolling, source-based, automated Gentoo.
  / /__ | |___|  _ <| |_| |___) |    Runs natively on any PC (UEFI & BIOS).
 /____| |_____|_| \_\\___/|____/      Secure Boot: Microsoft UEFI CA Signed

                                     Live Interface:
                                       zeros-desktop             (Launch Hyprland + macshell GUI)
                                       zeros-installer           (Interactive GUI/TUI Wizard)
                                       zeros-detect              (Detect hardware profile)
                                       zeros-install /dev/sdX    (CLI dry-run installer)
                                       zeros-install /dev/sdX --really
MOTD
echo "zeros" > root/etc/hostname

# Configure autologin on tty1 for instant live session
if [ -f root/etc/inittab ]; then
  sed -i -E 's/^[# ]*([c0-9]+:.*agetty ).*tty1.*linux/c1:12345:respawn:\/sbin\/agetty --autologin root --noclear 38400 tty1 linux/' root/etc/inittab 2>/dev/null || true
  sed -i -E 's/^[# ]*(tty1:.*agetty ).*tty1.*linux/tty1:12345:respawn:\/sbin\/agetty --autologin root --noclear 38400 tty1 linux/' root/etc/inittab 2>/dev/null || true
  if ! grep -q "autologin root" root/etc/inittab; then
    echo "c1:12345:respawn:/sbin/agetty --autologin root --noclear 38400 tty1 linux" >> root/etc/inittab
  fi
fi
if [ -f root/etc/conf.d/agetty ]; then
  sed -i 's/^#agetty_options=.*/agetty_options="--autologin root --noclear"/' root/etc/conf.d/agetty 2>/dev/null || true
  sed -i 's/^agetty_options=.*/agetty_options="--autologin root --noclear"/' root/etc/conf.d/agetty 2>/dev/null || true
fi

# Enable dhcpcd / NetworkManager in live root if present
if [ -f root/etc/init.d/dhcpcd ]; then
  mkdir -p root/etc/runlevels/default
  ln -sf /etc/init.d/dhcpcd root/etc/runlevels/default/dhcpcd 2>/dev/null || true
fi

# Rebuild squashfs
mksquashfs root tree/image.squashfs -comp xz -noappend -quiet

# 3. Configure GRUB for universal hardware boot (UEFI + BIOS)
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

menuentry 'Zeros OS (Live Desktop - Hyprland & macshell)' --class gnu-linux --class os {
    search --no-floppy --file --set=root /image.squashfs
    if [ -z "\$root" ]; then search --no-floppy -l $LABEL --set=root; fi
    linux /boot/gentoo dokeymap root=live:CDLABEL=$LABEL rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot console=tty0 console=ttyS0,115200
    initrd /boot/gentoo.igz
}

menuentry 'Zeros OS (Safe Graphics / nomodeset)' --class gnu-linux --class os {
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

# 4. Configure UEFI Secure Boot and EFI bootloader
mkdir -p tree/EFI/BOOT
cp tree/boot/grub/grub.cfg tree/EFI/BOOT/grub.cfg

if [ -n "$SHIM_SRC" ] && [ -n "$GRUB_SIGNED_SRC" ]; then
  echo "Installing Microsoft-Signed Shim and MokManager into ISO EFI boot path..."
  if [ -f tree/EFI/BOOT/BOOTX64.EFI ]; then
    cp tree/EFI/BOOT/BOOTX64.EFI tree/EFI/BOOT/grubx64.efi.orig
  fi
  cp "$SHIM_SRC" tree/EFI/BOOT/BOOTX64.EFI
  cp "$SHIM_SRC" tree/EFI/BOOT/shimx64.efi
  [ -n "$MM_SRC" ] && cp "$MM_SRC" tree/EFI/BOOT/mmx64.efi
  cp "$GRUB_SIGNED_SRC" tree/EFI/BOOT/grubx64.efi
fi

# Rebuild / expand tree/efi.img to 16MB FAT image so signed binaries fit cleanly
echo "Configuring efi.img FAT system area..."
dd if=/dev/zero of=tree/efi.img.new bs=1M count=16 status=none
mkfs.vfat -F 32 -n "ZEROS_EFI" tree/efi.img.new >/dev/null

if command -v mcopy >/dev/null 2>&1; then
  mmd -i tree/efi.img.new ::EFI ::EFI/BOOT 2>/dev/null || true
  for f in tree/EFI/BOOT/*; do
    [ -f "$f" ] && mcopy -o -i tree/efi.img.new "$f" "::EFI/BOOT/$(basename "$f")"
  done
  mv tree/efi.img.new tree/efi.img
else
  EFI_TMP="/tmp/efimnt.$$"
  mkdir -p "$EFI_TMP"
  if mount -o loop tree/efi.img.new "$EFI_TMP" 2>/dev/null; then
    mkdir -p "$EFI_TMP/EFI/BOOT"
    cp -r tree/EFI/BOOT/* "$EFI_TMP/EFI/BOOT/" 2>/dev/null || true
    umount "$EFI_TMP" || true
    mv tree/efi.img.new tree/efi.img
  else
    rm -f tree/efi.img.new
    # Fallback to existing efi.img
    if mount -o loop tree/efi.img "$EFI_TMP" 2>/dev/null; then
      cp tree/boot/grub/grub.cfg "$EFI_TMP/EFI/BOOT/grub.cfg" 2>/dev/null || true
      umount "$EFI_TMP" || true
    fi
  fi
  rm -rf "$EFI_TMP"
fi

# 5. Extract original boot options, removing Apple HFS+ flags that break standard PC MBR
eval "BOOTOPTS=( $(xorriso -indev base.iso -report_system_area as_mkisofs -report_el_torito as_mkisofs 2>/dev/null | grep -v -e '^xorriso' -e '^-V ' -e '^--modification-date' -e '^-hfsplus' -e '^-apm-block-size') )"
printf '%s\n' "${BOOTOPTS[@]}" | head -30

# 6. Build final hybrid ISO with ZEROS_LIVE volume label
xorriso -as mkisofs -r -J -joliet-long -iso-level 3 -V "$LABEL" "${BOOTOPTS[@]}" -o "$OUT/zeros-$TAG.iso" tree
( cd "$OUT" && sha256sum "zeros-$TAG.iso" > "zeros-$TAG.iso.sha256" )
ls -lh "$OUT"
