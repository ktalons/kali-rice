# shellcheck shell=bash
# HTB workflow: engagement scaffold, helper commands on PATH, x86_64 support.

HTB_ROOT="${HTB_ROOT:-$HOME/htb}"
HTB_STATE="${HTB_STATE:-$HOME/.htb}"

step "engagement directories"
mkdir -p "$HTB_ROOT"/{boxes,vpn,tools,loot} "$HTB_STATE"
ok "$HTB_ROOT/{boxes,vpn,tools,loot}"

# ~/htb holds HTB material. It is never a git repo and never syncs anywhere —
# HTB permits publishing solutions only for Tier 0 / retired / Starting Point
# content, and a per-file judgement call is a standing risk. Keeping the whole
# tree off any remote makes the question moot.
if [ ! -f "$HTB_ROOT/.gitignore" ]; then
  printf '*\n' > "$HTB_ROOT/.gitignore"
  ok "wrote $HTB_ROOT/.gitignore (blanket ignore)"
else
  skip "$HTB_ROOT/.gitignore already present"
fi
if [ ! -f "$HTB_ROOT/README.md" ]; then
  cat > "$HTB_ROOT/README.md" <<'EOF'
# HTB working directory

Machine and Challenge work. Local only — do not commit, sync, or publish
anything under this tree. HTB permits publishing solutions only for Tier 0
modules, retired Machines/Challenges/Sherlocks, and Starting Point.

Academy module notes live in the separate private vault, not here.

Layout:
  boxes/<name>/{nmap,loot,exploits,screenshots,notes.md}
  vpn/     .ovpn configs
  tools/   downloaded binaries
  loot/    cross-box credentials and artefacts
EOF
  ok "wrote $HTB_ROOT/README.md"
fi

step "helper commands"
mkdir -p "$HOME/.local/bin"
for f in "$RICE_ROOT"/bin/*; do
  link_file "$f" "$HOME/.local/bin/$(basename "$f")"
done

step "x86_64 emulation"
# aarch64 Kali cannot run x86_64 challenge binaries natively. qemu-user-binfmt
# registers binfmt_misc handlers so they execute transparently.
if [ -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
  ok "binfmt handler for x86_64 is registered"
else
  sudo systemctl restart binfmt-support 2>/dev/null || true
  sleep 1
  if [ -e /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
    ok "binfmt handler for x86_64 registered"
  else
    warn "no x86_64 binfmt handler — x86 binaries will fail with 'cannot execute'"
    warn "check: ls /proc/sys/fs/binfmt_misc/ && systemctl status binfmt-support"
  fi
fi

step "wallpaper"
WALL_DIR="$HOME/.local/share/wallpapers"
mkdir -p "$WALL_DIR"
# Personal wallpapers come from the Parallels shared folder rather than the
# repo — their provenance is unknown and this repo is public.
copied=0
for share in /media/psf/*/VMshare/kali /mnt/psf/*/VMshare/kali; do
  [ -d "$share" ] || continue
  for img in "$share"/*.png "$share"/*.jpg; do
    [ -f "$img" ] || continue
    dest="$WALL_DIR/$(basename "$img")"
    [ -f "$dest" ] || { cp "$img" "$dest" && copied=$((copied + 1)); }
  done
done
if [ "$copied" -gt 0 ]; then
  ok "copied $copied wallpaper(s) from the shared folder"
elif [ -n "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
  skip "wallpapers already in $WALL_DIR"
else
  warn "no wallpapers found — drop images in $WALL_DIR and re-run, or the desktop stays a flat colour"
fi
