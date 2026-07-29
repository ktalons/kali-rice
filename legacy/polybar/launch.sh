#!/usr/bin/env bash
# Launch polybar, replacing any instance already running. i3 calls this from
# exec_always, so it runs again on every reload.
set -euo pipefail

killall -q polybar 2>/dev/null || true
# Wait for the processes to actually die, otherwise the new bar races the old
# one for the same struts and you get a doubled or missing bar.
while pgrep -x polybar >/dev/null; do sleep 0.2; done

mkdir -p "$HOME/.cache"
polybar main --config="$HOME/.config/polybar/config.ini" \
  >"$HOME/.cache/polybar.log" 2>&1 &
disown
