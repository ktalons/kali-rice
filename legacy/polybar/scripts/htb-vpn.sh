#!/usr/bin/env bash
# Polybar: VPN state, read from the kernel every time. Never cached — a stale
# "connected" is worse than no indicator at all.
set -euo pipefail

read -r iface ip < <(
  ip -o -4 addr show 2>/dev/null \
    | awk '$2 ~ /^tun[0-9]+$/ {split($4, a, "/"); print $2, a[1]; exit}'
) || true

if [ -n "${ip:-}" ]; then
  printf '%%{F#a6e3a1}󰖂%%{F-} %%{F#cdd6f4}%s%%{F-}\n' "$ip"
else
  printf '%%{F#6c7086}󰖂 vpn down%%{F-}\n'
fi
