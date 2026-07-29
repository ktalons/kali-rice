#!/usr/bin/env bash
# Rofi power menu.
set -euo pipefail

choice=$(printf '󰌾 lock\n󰗽 logout\n󰜉 reboot\n󰐥 shutdown' \
  | rofi -dmenu -i -p "power" -theme-str 'window {width: 20%;}')

case "$choice" in
  *lock)     command -v betterlockscreen >/dev/null && betterlockscreen -l dim || i3lock -c 1e1e2e ;;
  *logout)   i3-msg exit ;;
  *reboot)   systemctl reboot ;;
  *shutdown) systemctl poweroff ;;
esac
