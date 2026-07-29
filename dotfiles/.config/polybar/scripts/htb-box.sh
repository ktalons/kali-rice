#!/usr/bin/env bash
# Polybar: the current HTB box, or nothing at all when none is set.
set -euo pipefail

f="${HTB_STATE:-$HOME/.htb}/box"
[ -s "$f" ] || exit 0

printf '%%{F#cba6f7}%%{F-} %%{F#cdd6f4}%s%%{F-}\n' "$(cat "$f")"
