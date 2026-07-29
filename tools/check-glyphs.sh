#!/usr/bin/env bash
#
# check-glyphs.sh — verify every Nerd Font glyph in the configs is real and
# renderable.
#
# Catches two failure modes that both look identical on screen (a missing
# icon) and neither of which produces an error anywhere:
#
#   1. A glyph got dropped from a config during editing. Some tooling
#      silently eats Private Use Area characters, leaving `format-prefix = " "`
#      with nothing in it. Every icon in this repo was lost this way once.
#   2. The font that would supply a glyph is not installed. polybar does not
#      fail on a missing font — it substitutes whatever fontconfig returns
#      (usually DejaVu Sans, which has no Nerd Font coverage) and logs the
#      substitution as a normal "Loaded font" line.
#
# Usage: tools/check-glyphs.sh [--font "JetBrainsMono Nerd Font"]
set -euo pipefail

FONT="${2:-JetBrainsMono Nerd Font}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Files expected to contain glyphs, and how many. A count that drops is the
# signal something ate a character.
#
# Deliberately a plain list rather than an associative array: macOS ships
# bash 3.2, which has no `declare -A`, and this needs to run on the host
# before a commit as well as in the guest.
EXPECTED="
dotfiles/.config/i3/config:5
dotfiles/.config/polybar/config.ini:5
dotfiles/.config/polybar/scripts/htb-vpn.sh:2
dotfiles/.config/polybar/scripts/htb-target.sh:1
dotfiles/.config/polybar/scripts/htb-box.sh:1
dotfiles/.config/polybar/scripts/powermenu.sh:4
dotfiles/.config/starship.toml:2
dotfiles/.config/rofi/config.rasi:3
dotfiles/.tmux.conf:1
"

fail=0

printf '\n== glyph counts ==\n'
for entry in $EXPECTED; do
  f="${entry%:*}"
  want="${entry##*:}"
  if [ ! -f "$f" ]; then
    printf '  MISSING  %s\n' "$f"; fail=1; continue
  fi
  got=$(python3 - "$f" <<'PY'
import sys
t = open(sys.argv[1], encoding='utf-8').read()
print(sum(1 for c in t if 0xE000 <= ord(c) <= 0xF8FF or 0xF0000 <= ord(c) <= 0xFFFFD))
PY
)
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %2d/%-2d  %s\n' "$got" "$want" "$f"
  else
    printf '  FAIL  %2d/%-2d  %s\n' "$got" "$want" "$f"; fail=1
  fi
done

printf '\n== font coverage (%s) ==\n' "$FONT"
if ! command -v fc-list >/dev/null; then
  printf '  SKIP  fc-list not available (run this in the guest)\n'
else
  # Every distinct codepoint actually used across the repo.
  cps=$(python3 - <<'PY'
import pathlib
seen=set()
for p in pathlib.Path('dotfiles').rglob('*'):
    if not p.is_file(): continue
    try: t=p.read_text(encoding='utf-8')
    except Exception: continue
    for c in t:
        o=ord(c)
        if 0xE000<=o<=0xF8FF or 0xF0000<=o<=0xFFFFD: seen.add(o)
print(' '.join(f'{o:05X}' for o in sorted(seen)))
PY
)
  for cp in $cps; do
    n=$(fc-list ":charset=$cp" family 2>/dev/null | grep -ci "$FONT" || true)
    if [ "$n" -gt 0 ]; then
      printf '  ok    U+%s\n' "$cp"
    else
      printf '  FAIL  U+%s  not in %s — will render as tofu\n' "$cp" "$FONT"; fail=1
    fi
  done
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
  printf '  all glyphs present and covered.\n\n'
else
  printf '  glyph check FAILED — icons will be missing or tofu.\n\n'
fi
exit "$fail"
