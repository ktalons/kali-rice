#!/usr/bin/env bash
# Set the wallpaper, falling back to a flat Catppuccin base colour so the
# desktop never comes up as an unstyled grey X root window.
set -euo pipefail

WALL_DIR="$HOME/.local/share/wallpapers"
BASE="#1e1e2e"

pick=""
if [ -d "$WALL_DIR" ]; then
  # A file named `default.*` wins; otherwise take the first image present.
  for c in "$WALL_DIR"/default.*; do [ -f "$c" ] && { pick="$c"; break; }; done
  if [ -z "$pick" ]; then
    pick=$(find "$WALL_DIR" -maxdepth 1 -type f \
             \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
             | sort | head -1)
  fi
fi

if [ -n "$pick" ] && command -v feh >/dev/null; then
  feh --no-fehbg --bg-fill "$pick"
elif command -v xsetroot >/dev/null; then
  xsetroot -solid "$BASE"
fi
