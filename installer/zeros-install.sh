#!/usr/bin/env bash
# Zeros installer skeleton. DRY RUN by default: prints every destructive step.
# Usage: zeros-install.sh /dev/sdX [--really]
set -euo pipefail
DISK=${1:?usage: $0 /dev/sdX [--really]}
GO=${2:-}
run() { echo "+ $*"; [[ $GO == --really ]] && "$@" || true; }

PROFILE=$(python3 -m zeros.detect)
KEY=$(echo "$PROFILE" | python3 -c 'import sys,json;print(json.load(sys.stdin)["cache_key"])')
echo "Hardware profile cache key: $KEY"

run parted -s "$DISK" mklabel gpt mkpart ESP fat32 1MiB 513MiB set 1 esp on mkpart root btrfs 513MiB 100%
run mkfs.fat -F32 "${DISK}1"
run mkfs.btrfs -f "${DISK}2"
run mount "${DISK}2" /mnt/gentoo
run btrfs subvolume create /mnt/gentoo/@
run btrfs subvolume create /mnt/gentoo/@snapshots
# 1) try binary cache for this profile (GitHub Releases asset "cache-$KEY"), 2) else compile locally
run bash -c "curl -fsSL https://github.com/halxo/zeros/releases/download/rolling-cache/cache-$KEY.tar.zst | tar -C /mnt/gentoo -I zstd -x || echo 'no cache: compiling locally'"
run bash -c "python3 -m zeros.detect --make-conf > /mnt/gentoo/etc/portage/make.conf"
run chroot /mnt/gentoo emerge --sync
run chroot /mnt/gentoo emerge -uDN @world zeros-meta
echo "Kernel: build with zeros.kernel.build_script(latest_stable())"
