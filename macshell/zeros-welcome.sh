#!/usr/bin/env bash
# Zeros OS First-Boot Welcome Wizard
set -euo pipefail

UI=""
if command -v whiptail >/dev/null 2>&1; then
  UI="whiptail"
elif command -v dialog >/dev/null 2>&1; then
  UI="dialog"
fi

if [ -z "$UI" ]; then
  echo "Welcome to Zeros OS!"
  echo "Run 'nmtui' to connect to Wi-Fi, or 'zeros-update update' to check for updates."
  exit 0
fi

TITLE="Welcome to Zeros OS"

while true; do
  CHOICE=$($UI --title "$TITLE" --menu \
"Welcome to Zeros OS!
Your hardware-tailored, rolling-release operating system.

What would you like to configure?" 16 65 6 \
  "1" "Connect to Wi-Fi / Network (nmtui)" \
  "2" "Check Hardware Profile (zeros-detect)" \
  "3" "Check for Rolling System Updates (zeros-update)" \
  "4" "Launch Desktop Session (Hyprland)" \
  "5" "Open Terminal Shell" \
  "6" "Exit" 3>&1 1>&2 2>&3)

  case "$CHOICE" in
    1)
      if command -v nmtui >/dev/null 2>&1; then
        nmtui
      else
        $UI --title "$TITLE" --msgbox "NetworkManager (nmtui) is not active." 8 45
      fi
      ;;
    2)
      PROF=$(zeros-detect 2>/dev/null || python3 -m zeros.detect 2>/dev/null || echo "Unable to detect profile")
      $UI --title "Hardware Profile" --msgbox "$PROF" 20 70
      ;;
    3)
      $UI --title "$TITLE" --infobox "Checking and applying rolling updates..." 8 50
      zeros-update update 2>&1 | tee /tmp/update.log || true
      $UI --title "$TITLE" --textbox /tmp/update.log 18 70
      ;;
    4)
      if command -v Hyprland >/dev/null 2>&1; then
        exec Hyprland
      else
        $UI --title "$TITLE" --msgbox "Hyprland is not installed or not in PATH." 8 45
      fi
      ;;
    5)
      clear
      echo "Entering Zeros shell. Type 'exit' to return to welcome menu."
      bash
      ;;
    6|*)
      break
      ;;
  esac
done
