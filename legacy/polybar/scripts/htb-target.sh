#!/usr/bin/env bash
# Polybar: the current HTB target, or nothing at all when none is set.
set -euo pipefail

f="${HTB_STATE:-$HOME/.htb}/target"
[ -s "$f" ] || exit 0

printf '%%{F#f38ba8}󰓾%%{F-} %%{F#cdd6f4}%s%%{F-}\n' "$(cat "$f")"
