#!/bin/sh
# /etc/profile.d/zeros-session.sh
# Auto-detects display hardware and launches Graphical Live Desktop or TUI Installer on tty1.

if [ "$(tty 2>/dev/null)" = "/dev/tty1" ] && [ -z "${ZEROS_SESSION_STARTED:-}" ]; then
  export ZEROS_SESSION_STARTED=1

  # Test if graphical hardware / DRM is present
  HAS_DRM=0
  if [ -d /sys/class/drm ]; then
    for card in /sys/class/drm/card*-*; do
      if [ -e "$card" ]; then
        HAS_DRM=1
        break
      fi
    done
  fi
  if [ -c /dev/fb0 ]; then
    HAS_DRM=1
  fi

  # Launch Graphical Live Session if graphical hardware and Hyprland are available
  if [ "$HAS_DRM" -eq 1 ] && command -v Hyprland >/dev/null 2>&1; then
    echo "Starting Zeros Graphical Live Session (Hyprland + macshell)..."
    exec /usr/local/bin/zeros-desktop
  fi

  # Otherwise launch interactive TUI installer on tty1
  if [ -t 0 ] && [ -t 1 ]; then
    echo "Starting Zeros OS Installer..."
    sleep 1
    zeros-installer || true
  fi
fi
