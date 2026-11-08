#!/usr/bin/env bash
# Remaster the official Gentoo minimal install ISO into the Zeros live/installer ISO.
# Needs root (squashfs preserves ownership): run in CI or `sudo`.
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
if [ -s base.iso.sha256 ]; then (grep -h "\.iso" base.iso.sha256 | awk '{print $1"  base.iso"}' | head -1 | sha256sum -c -); fi
# extract the whole ISO tree (so we can rebuild it with the original boot setup)
xorriso -osirrox on -indev base.iso -extract / tree >/dev/null
chmod -R u+w tree
mv tree/image.squashfs image.squashfs
unsquashfs -d root image.squashfs
# ---- inject Zeros ----
install -d root/usr/lib/zeros/python root/usr/local/bin root/etc/skel/.config
cp -r "$REPO/zeros_py/zeros" root/usr/lib/zeros/python/
cp "$REPO/installer/zeros-install.sh" root/usr/local/bin/zeros-install
for t in detect:zeros-detect updater:zeros-update; do
  printf '#!/bin/sh\nPYTHONPATH=/usr/lib/zeros/python exec python3 -m zeros.%s "$@"\n' "${t%%:*}" > "root/usr/local/bin/${t##*:}"
done
sed -i 's#python3 -m zeros.detect#zeros-detect#g' root/usr/local/bin/zeros-install
chmod +x root/usr/local/bin/*
cp -r "$REPO/overlay" root/usr/share/zeros-overlay
cp -r "$REPO/macshell" root/usr/share/zeros-macshell
cat > root/etc/motd <<MOTD

   ____  _____ ____   ___  ____
  |_  / | ____|  _ \ / _ \/ ___|     Zeros live ISO  ($TAG)
   / /  |  _| | |_) | | | \___ \     Rolling, source-based, built for YOUR hardware.
  / /__ | |___|  _ <| |_| |___) |
 /____| |_____|_| \_\\___/|____/     1. zeros-detect          (show hardware profile)
                                     2. zeros-install /dev/sdX  (DRY RUN: prints plan)
                                     3. zeros-install /dev/sdX --really   (installs!)
MOTD
echo "zeros" > root/etc/hostname
mksquashfs root tree/image.squashfs -comp xz -noappend -quiet
# ---- rebuild ISO with the ORIGINAL boot records (BIOS + UEFI hybrid) ----
# Replaying boot data in-place breaks on the hybrid GPT; as_mkisofs reproduces it for a fresh image.
eval "BOOTOPTS=( $(xorriso -indev base.iso -report_system_area as_mkisofs -report_el_torito as_mkisofs 2>/dev/null | grep -v -e '^xorriso' -e '^-V ' -e '^--modification-date') )"
printf '%s\n' "${BOOTOPTS[@]}" | head -30
xorriso -as mkisofs -r -J -joliet-long -iso-level 3 -V "ZEROS_LIVE" "${BOOTOPTS[@]}" -o "$OUT/zeros-$TAG.iso" tree
( cd "$OUT" && sha256sum "zeros-$TAG.iso" > "zeros-$TAG.iso.sha256" )
ls -lh "$OUT"
