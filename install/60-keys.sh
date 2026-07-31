# shellcheck shell=bash
# Keyboard shortcuts: the launcher and HTB bindings the i3 rice had.
#
# The i3 config carried the whole workflow on the keyboard — a terminal, rofi,
# screenshots into the current box, and rofi prompts for target and box. All of
# it lived in `legacy/i3/config` and none of it survived the move to XFCE,
# because XFCE keeps shortcuts in xfconf rather than in a config file. This
# step puts them back.
#
# Deliberately NOT restored: the i3 focus/move/split/resize bindings. Those
# drive a tiling layout that no longer exists — XFCE floats windows and the
# bottom taskbar switches between them. Also not restored: the XF86Audio*
# keys, which xfsettingsd already handles natively.
#
# MUST run inside a live XFCE session, same as 50-xfce.sh.

step "session check"
xfconf_session_ready || return 0

KCHAN=xfce4-keyboard-shortcuts
KEY_FAILED=0

# The htb-* helpers are symlinked into ~/.local/bin by 40-htb.sh. Shortcuts
# are spawned by xfsettingsd, which inherits the session's PATH — and that
# comes from the login shell, not from .zshrc. If ~/.local/bin is not on it,
# every HTB key does nothing at all and says nothing about why. Bind the
# absolute path instead of relying on the lookup. @BIN@ below is substituted
# with this; the heredocs are quoted so $-expressions reach the shell intact.
HTB_BIN="$HOME/.local/bin"
if [ ! -x "$HTB_BIN/htb-shot" ]; then
  warn "$HTB_BIN/htb-shot is missing — run ./bootstrap.sh 40 first,"
  warn "otherwise the HTB keys below will be bound to nothing."
fi

# --- how XFCE stores this --------------------------------------------------
#
# Two trees per base: /<base>/default/<key> and /<base>/custom/<key>, where
# base is `commands` (run a program) or `xfwm4` (a window manager action).
# The custom tree wins, but ONLY once /<base>/custom/override is true.
#
# That flag is the trap. Setting override=true means "custom is the complete
# list" — every stock shortcut not present in custom is simply gone. Flip it
# on a fresh profile and you silently lose xflock4, xfrun4, the screenshot
# key, the lot. So copy the defaults across first, exactly as the Settings
# dialog does, and only then flip it.
seed_custom() {
  local base="$1" ov n=0 line prop val leaf
  ov=$(xfconf-query -c "$KCHAN" -p "/$base/custom/override" 2>/dev/null || true)
  if [ "$ov" = "true" ]; then
    skip "/$base/custom already overrides the defaults"
    return 0
  fi
  while IFS= read -r line; do
    prop=${line%%[[:space:]]*}
    case "$prop" in "/$base/default/"*) ;; *) continue ;; esac
    leaf=${prop#"/$base/default/"}
    val=${line#"$prop"}
    val=${val#"${val%%[![:space:]]*}"}     # strip the leading whitespace run
    [ -n "$leaf" ] && [ -n "$val" ] || continue
    # -lv renders non-scalar properties as <<UNSUPPORTED>>; copying that
    # string across would bind the key to a command literally named that.
    case "$val" in *'<<UNSUPPORTED>>'*) continue ;; esac
    xfconf-query -c "$KCHAN" -p "/$base/custom/$leaf" --create -t string -s "$val" \
      >/dev/null 2>&1 && n=$((n + 1))
  done < <(xfconf-query -c "$KCHAN" -lv 2>/dev/null)
  xfconf-query -c "$KCHAN" -p "/$base/custom/override" --create -t bool -s true \
    >/dev/null 2>&1 || die "could not set /$base/custom/override"
  ok "copied $n default $base shortcut(s) into custom, then enabled override"
}

# Normalise a shortcut name so two spellings of one key compare equal.
#
# The property name is a literal string, but XFCE matches it by parsing, so
# `<Super><Shift>b` and `<Shift><Super>b` are the same shortcut stored under
# two different properties — and both stay live, fighting each other. Compare
# on the modifier SET plus the keysym, not on the spelling.
norm_key() {
  local k="$1" key rest mods
  key="${k##*>}"
  rest="${k%"$key"}"
  mods=$(printf '%s' "$rest" | tr -d '<' | tr '>' '\n' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/^primary$/control/' -e 's/^ctrl$/control/' -e 's/^mod1$/alt/' \
    | grep -v '^$' | sort -u | paste -sd, -)
  printf '%s|%s' "$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')" "$mods"
}

# Drop any existing binding on the same key, in either base. xfwm4 grabs keys
# before the command shortcuts get a look, so a leftover WM binding on a key
# we want makes our command look like it simply does not fire.
#
# $3 is the base being written to. The exact property name is left alone only
# there — that one is about to be overwritten with the new value. In the OTHER
# base an identically named property is a genuine collision and has to go:
# XFCE ships <Super>d on xfwm4's show_desktop_key, which is precisely the key
# rofi wants, and leaving it bound means rofi silently never opens.
free_key() {
  local base="$1" key="$2" target="$3" want prop leaf
  want=$(norm_key "$key")
  while IFS= read -r prop; do
    leaf=${prop#"/$base/custom/"}
    [ "$leaf" = "override" ] && continue
    [ "$leaf" = "$key" ] && [ "$base" = "$target" ] && continue
    [ "$(norm_key "$leaf")" = "$want" ] || continue
    xfconf-query -c "$KCHAN" -p "$prop" -r >/dev/null 2>&1 \
      && warn "unbound $leaf ($base) — it collided with $key"
  done < <(xfconf-query -c "$KCHAN" -l 2>/dev/null | grep "^/$base/custom/")
}

# Bind and read back. Failures are collected rather than fatal: dying on the
# first bad key would leave the other twenty unset, which is the half-applied
# state this repo works hard to avoid.
kbind() {
  local base="$1" key="$2" val="$3" prop cur
  prop="/$base/custom/$key"
  free_key commands "$key" "$base"
  free_key xfwm4    "$key" "$base"
  cur=$(xfconf-query -c "$KCHAN" -p "$prop" 2>/dev/null || true)
  if [ "$cur" = "$val" ]; then
    skip "$key already -> $val"
    return 0
  fi
  if ! xfconf-query -c "$KCHAN" -p "$prop" --create -t string -s "$val" >/dev/null 2>&1; then
    warn "could not bind $key"; KEY_FAILED=$((KEY_FAILED + 1)); return 0
  fi
  cur=$(xfconf-query -c "$KCHAN" -p "$prop" 2>/dev/null || true)
  if [ "$cur" != "$val" ]; then
    warn "$key did not stick (wanted '$val', got '$cur')"
    KEY_FAILED=$((KEY_FAILED + 1)); return 0
  fi
  ok "$key -> $val"
}

# --- backup ----------------------------------------------------------------
step "shortcut backup"
KEYS_BACKUP="$HOME/.rice-backup/keyboard-shortcuts-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$KEYS_BACKUP")"
if xfconf-query -c "$KCHAN" -lv > "$KEYS_BACKUP" 2>/dev/null; then
  ok "saved current shortcuts to ${KEYS_BACKUP#"$HOME"/}"
else
  warn "could not dump the current shortcuts — continuing"
fi

step "custom shortcut trees"
seed_custom commands
seed_custom xfwm4

# --- launching -------------------------------------------------------------
step "launchers"
# rofi has been installed, themed and linked since the first commit, but
# nothing has launched it since i3 went away. These are the keys that make it
# part of the desktop again.
while IFS='|' read -r key cmd; do
  [ -n "$key" ] || continue
  kbind commands "$key" "$cmd"
done <<'KEYS'
<Super>Return|kitty
<Super>d|rofi -show drun
<Super>space|rofi -show drun
<Super><Shift>d|rofi -show run
<Super>w|rofi -show window
<Super>e|thunar
<Super>b|firefox
KEYS

# <Super>c briefly opened a clipman history popup. The plugin errored on this
# guest and the feature was dropped, but deleting the line above does not
# unbind the key — it would just sit there launching a command that no longer
# resolves, which is a dead key that reports nothing. Take it back out, and
# only if it still holds the binding this repo set.
STALE_C=$(xfconf-query -c "$KCHAN" -p '/commands/custom/<Super>c' 2>/dev/null || true)
if [ "$STALE_C" = "xfce4-popup-clipman" ]; then
  xfconf-query -c "$KCHAN" -p '/commands/custom/<Super>c' -r >/dev/null 2>&1 \
    && ok "unbound <Super>c (clipman was removed)" \
    || warn "could not unbind the stale <Super>c"
else
  skip "<Super>c is not bound to clipman"
fi

# --- HTB -------------------------------------------------------------------
step "HTB workflow"
# Print overrides XFCE's own xfce4-screenshooter binding on purpose: htb-shot
# files the capture in the current box's screenshots/ and puts the path on the
# clipboard, which is the whole point of having it.
#
# The rofi prompts read from /dev/null so dmenu opens with an empty list —
# whatever gets typed comes back as the selection.
while IFS='|' read -r key cmd; do
  [ -n "$key" ] || continue
  kbind commands "$key" "${cmd//@BIN@/$HTB_BIN}"
done <<'KEYS'
Print|@BIN@/htb-shot
<Shift>Print|@BIN@/htb-shot full
<Super>Print|@BIN@/htb-shot
<Super>t|sh -c 'v=$(rofi -dmenu -p target < /dev/null) && [ -n "$v" ] && @BIN@/htb-target "$v"'
<Super><Shift>b|sh -c 'v=$(rofi -dmenu -p box < /dev/null) && [ -n "$v" ] && kitty -e @BIN@/htb-box "$v"'
<Super>v|kitty -e sh -c '@BIN@/htb-vpn status; echo; read -r _'
KEYS

# --- window manager --------------------------------------------------------
step "window manager keys"
# The handful of i3 bindings that have a real XFCE equivalent. These are
# xfwm4 actions, not commands, so they live in the other base.
while IFS='|' read -r key action; do
  [ -n "$key" ] || continue
  kbind xfwm4 "$key" "$action"
done <<'KEYS'
<Super>q|close_window_key
<Super>f|fullscreen_key
<Super>1|workspace_1_key
<Super>2|workspace_2_key
<Super>3|workspace_3_key
<Super>4|workspace_4_key
KEYS

# --- result ----------------------------------------------------------------
if [ "$KEY_FAILED" -gt 0 ]; then
  printf '\n'
  warn "$KEY_FAILED shortcut(s) did not apply. The rest did."
  warn "Restore the previous set with:"
  warn "  while read -r p v; do xfconf-query -c $KCHAN -p \"\$p\" --create -t string -s \"\$v\"; done < ${KEYS_BACKUP/#"$HOME"/\~}"
else
  ok "every shortcut applied"
fi

# xfsettingsd and xfwm4 both watch xfconf, so the new bindings are live
# immediately — no restart, no logout.
ok "bindings are live now (xfsettingsd picks them up from xfconf)"
