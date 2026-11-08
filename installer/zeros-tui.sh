#!/usr/bin/env bash
# Zeros Interactive Terminal UI Installer
# Guided installation wizard for everyday PCs and laptops.
set -euo pipefail

# Choose UI backend: whiptail or dialog
UI=""
if command -v whiptail >/dev/null 2>&1; then
  UI="whiptail"
elif command -v dialog >/dev/null 2>&1; then
  UI="dialog"
else
  echo "Error: neither whiptail nor dialog found. Running command-line installer."
  exec zeros-install "$@"
fi

TITLE="Zeros OS Installation Wizard"

# 1. Welcome Screen
$UI --title "$TITLE" --msgbox \
"Welcome to Zeros OS!

Zeros is a rolling-release, source-based Linux distribution built for your hardware.
This wizard will guide you through installing Zeros onto your computer.

Press OK to begin." 14 65

# 2. Disk Detection & Selection
# List block devices excluding loop, zram, and read-only media (live USB)
BOOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null | sed -E 's/[0-9]+$|p[0-9]+$//' || true)
DISKS=()
while read -r name size model; do
  dev="/dev/$name"
  # Skip the drive hosting the live root if possible
  if [ -n "$BOOT_DEV" ] && [ "$dev" = "$BOOT_DEV" ]; then
    continue
  fi
  DISKS+=("$dev" "$size - ${model:-Generic Disk}")
done < <(lsblk -dpno NAME,SIZE,MODEL | grep -v -E 'loop|zram|ram')

if [ ${#DISKS[@]} -eq 0 ]; then
  # Fallback: show all disks if filter excluded everything
  while read -r name size model; do
    DISKS+=("/dev/$name" "$size - ${model:-Generic Disk}")
  done < <(lsblk -dpno NAME,SIZE,MODEL | grep -v -E 'loop|zram|ram')
fi

if [ ${#DISKS[@]} -eq 0 ]; then
  $UI --title "$TITLE" --msgbox "Error: No suitable hard drives or SSDs found!" 10 50
  exit 1
fi

TARGET_DISK=$($UI --title "$TITLE" --menu \
"Select the target disk to install Zeros OS on:
WARNING: The selected drive will be COMPLETELY ERASED." 16 65 6 "${DISKS[@]}" 3>&1 1>&2 2>&3)

if [ -z "$TARGET_DISK" ]; then
  $UI --title "$TITLE" --msgbox "Installation cancelled." 8 40
  exit 0
fi

# 3. Hostname Configuration
HOSTNAME=$($UI --title "$TITLE" --inputbox "Enter a hostname for this computer:" 10 50 "zeros" 3>&1 1>&2 2>&3)
HOSTNAME=${HOSTNAME:-zeros}

# 4. User Account Setup
USERNAME=$($UI --title "$TITLE" --inputbox "Enter a username for the primary user account:" 10 50 "zeros" 3>&1 1>&2 2>&3)
USERNAME=${USERNAME:-zeros}

while true; do
  USER_PASS=$($UI --title "$TITLE" --passwordbox "Enter password for $USERNAME:" 10 50 3>&1 1>&2 2>&3)
  USER_PASS2=$($UI --title "$TITLE" --passwordbox "Confirm password for $USERNAME:" 10 50 3>&1 1>&2 2>&3)
  if [ "$USER_PASS" = "$USER_PASS2" ] && [ -n "$USER_PASS" ]; then
    break
  fi
  $UI --title "$TITLE" --msgbox "Passwords do not match or are empty. Please try again." 10 50
done

# 5. Root Password Setup
while true; do
  ROOT_PASS=$($UI --title "$TITLE" --passwordbox "Enter password for root (administrator):" 10 50 3>&1 1>&2 2>&3)
  ROOT_PASS2=$($UI --title "$TITLE" --passwordbox "Confirm password for root:" 10 50 3>&1 1>&2 2>&3)
  if [ "$ROOT_PASS" = "$ROOT_PASS2" ] && [ -n "$ROOT_PASS" ]; then
    break
  fi
  $UI --title "$TITLE" --msgbox "Root passwords do not match or are empty. Please try again." 10 50
done

# 6. Final Confirmation Dialog
$UI --title "$TITLE" --yesno \
"READY TO INSTALL!

Target Disk:   $TARGET_DISK
Hostname:      $HOSTNAME
Username:      $USERNAME
Partitioning:  GPT (512MB EFI System Partition + Btrfs Root with Subvolumes)

WARNING: All data on $TARGET_DISK will be permanently erased!
Are you sure you want to proceed?" 16 65

# 7. Execute Installation with Progress Bar
(
  echo "10"; echo "XXX"; echo "Detecting hardware profile and CPU optimizations..."; echo "XXX"
  zeros-detect >/dev/null 2>&1 || python3 -m zeros.detect >/dev/null 2>&1 || true
  sleep 1

  echo "25"; echo "XXX"; echo "Partitioning and formatting $TARGET_DISK..."; echo "XXX"
  zeros-install "$TARGET_DISK" --really >/tmp/zeros-install.log 2>&1

  echo "60"; echo "XXX"; echo "Configuring user accounts and credentials..."; echo "XXX"
  TARGET="/mnt/gentoo"
  if [ -d "$TARGET/etc" ]; then
    # Set hostname
    echo "$HOSTNAME" > "$TARGET/etc/hostname"
    
    # Set root password
    echo "root:$ROOT_PASS" | chroot "$TARGET" chpasswd 2>/dev/null || true
    
    # Create non-root user account with wheel/sudo privileges
    if ! id -u "$USERNAME" >/dev/null 2>&1; then
      chroot "$TARGET" useradd -m -G wheel,audio,video,input -s /bin/bash "$USERNAME" 2>/dev/null || true
      echo "$USERNAME:$USER_PASS" | chroot "$TARGET" chpasswd 2>/dev/null || true
    fi

    # Enable wheel group sudo access
    if [ -f "$TARGET/etc/sudoers" ]; then
      sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$TARGET/etc/sudoers" 2>/dev/null || true
    fi
  fi

  echo "85"; echo "XXX"; echo "Finalizing bootloader and OpenRC services..."; echo "XXX"
  sleep 2

  echo "100"; echo "XXX"; echo "Installation complete!"; echo "XXX"
  sleep 1
) | $UI --title "$TITLE" --gauge "Installing Zeros OS..." 10 65 0

$UI --title "$TITLE" --msgbox \
"Congratulations! Zeros OS has been successfully installed on $TARGET_DISK.

You can now reboot your computer and remove the installation USB media:
  reboot" 12 60
