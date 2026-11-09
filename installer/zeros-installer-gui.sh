#!/usr/bin/env bash
# Zeros OS Graphical Installer launcher
# Runs zeros-installer in an available terminal emulator with appropriate window class
set -euo pipefail

# Avoid multiple concurrent instances
if pidof -x zeros-tui.sh >/dev/null 2>&1 || pidof -x zeros-tui >/dev/null 2>&1; then
  exit 0
fi

CMD="zeros-installer"

if command -v kitty >/dev/null 2>&1; then
  exec kitty --class zeros-installer --title "Zeros Installer" -o font_size=13 -o background_opacity=0.92 "$CMD"
elif command -v alacritty >/dev/null 2>&1; then
  exec alacritty --class zeros-installer,zeros-installer --title "Zeros Installer" -e "$CMD"
elif command -v foot >/dev/null 2>&1; then
  exec foot --app-id zeros-installer --title "Zeros Installer" "$CMD"
elif command -v xfce4-terminal >/dev/null 2>&1; then
  exec xfce4-terminal --title="Zeros Installer" --geometry=100x32 -e "$CMD"
elif command -v xterm >/dev/null 2>&1; then
  exec xterm -class zeros-installer -title "Zeros Installer" -geometry 100x35 -fa "Monospace" -fs 11 -e "$CMD"
else
  exec "$CMD"
fi
