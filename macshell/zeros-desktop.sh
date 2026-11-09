#!/usr/bin/env bash
# Zeros Desktop Session Starter
# Prepares user desktop config and launches Hyprland macshell
set -euo pipefail

# Ensure XDG runtime directory exists and has 0700 permissions
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Seed user config from /usr/share/zeros-macshell if not present
mkdir -p "$HOME/.config"
for app in hypr waybar wofi; do
  if [ -d "/usr/share/zeros-macshell/$app" ] && [ ! -d "$HOME/.config/$app" ]; then
    cp -r "/usr/share/zeros-macshell/$app" "$HOME/.config/$app" 2>/dev/null || true
  fi
done

# Seed Desktop shortcuts
mkdir -p "$HOME/Desktop" "$HOME/.local/share/applications" 2>/dev/null || true
if [ -d "/usr/share/zeros-macshell/applications" ]; then
  cp -r /usr/share/zeros-macshell/applications/*.desktop "$HOME/Desktop/" 2>/dev/null || true
  cp -r /usr/share/zeros-macshell/applications/*.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
fi

# Launch Hyprland if available, otherwise launch installer
if command -v Hyprland >/dev/null 2>&1; then
  exec Hyprland
else
  echo "Hyprland is not available. Falling back to terminal environment."
  exec zeros-installer
fi
