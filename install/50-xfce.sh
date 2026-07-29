# shellcheck shell=bash
# XFCE: Catppuccin Mocha theming, a bottom taskbar, and the HTB indicator.
#
# MUST be run from inside a running XFCE session. xfconf-query talks to
# xfconfd over the session bus; with no session the calls fail and the
# desktop stays stock. An earlier version of this repo wrapped them in
# `|| true`, so they failed silently and every theme property stayed empty
# while the script reported success. That is the bug this file exists to
# not repeat: every set is read back and verified.

step "session check"
if ! xfconf-query -c xsettings -l >/dev/null 2>&1; then
  # Loud, and recorded in the final summary — but not fatal, so a full
  # bootstrap run from a TTY still completes every other step.
  RICE_XFCE_SKIPPED=1
  printf '\n'
  warn "SKIPPING the entire XFCE step — no session on the bus."
  warn "Nothing here was applied. The desktop is still stock."
  warn ""
  warn "Log into XFCE (pick 'Xfce Session' at the greeter), open a terminal"
  warn "there, and run:   ./bootstrap.sh 50"
  warn ""
  warn "xfconf-query needs xfconfd on the session bus. From i3, a TTY, or over"
  warn "prlctl there is nothing to talk to and every setting is discarded."
  printf '\n'
  return 0
fi
ok "xfconfd is reachable"

# --- helpers ---------------------------------------------------------------

# Set a property and read it back. Anything that does not stick is fatal,
# not a warning — a theme that half-applied is worse than one that did not.
xset() {
  local channel="$1" prop="$2" type="$3" value="$4"
  local current
  current=$(xfconf-query -c "$channel" -p "$prop" 2>/dev/null || true)
  if [ "$current" = "$value" ]; then
    skip "$channel$prop already = $value"
    return 0
  fi
  xfconf-query -c "$channel" -p "$prop" --create -t "$type" -s "$value" >/dev/null 2>&1 \
    || die "failed to set $channel$prop"
  current=$(xfconf-query -c "$channel" -p "$prop" 2>/dev/null || true)
  [ "$current" = "$value" ] \
    || die "$channel$prop did not stick (wanted '$value', got '$current')"
  ok "$channel$prop = $value"
}

# --- theme discovery -------------------------------------------------------
step "locating the Catppuccin theme"
# Never hardcode the directory name. The catppuccin/gtk project has changed
# its release naming more than once (Catppuccin-Mocha-Standard-Lavender-Dark
# vs catppuccin-mocha-mauve-standard+default), and a hardcoded name that no
# longer exists is exactly how the theme silently failed to apply before.
THEME=""
for d in "$HOME/.local/share/themes"/*atppuccin*[Mm]ocha* /usr/share/themes/*atppuccin*[Mm]ocha*; do
  [ -d "$d" ] || continue
  case "$d" in *hdpi*) continue ;; esac   # skip the HiDPI variants
  THEME="$(basename "$d")"
  THEME_DIR="$d"
  break
done

if [ -z "$THEME" ]; then
  die "no Catppuccin Mocha theme found in ~/.local/share/themes or /usr/share/themes.

  Install one from https://github.com/catppuccin/gtk/releases and unzip it
  into ~/.local/share/themes, then re-run:  ./bootstrap.sh 50"
fi
ok "found $THEME"

if [ -d "$THEME_DIR/xfwm4" ]; then
  ok "theme ships an xfwm4/ directory — window borders will be themed too"
  XFWM_THEME="$THEME"
else
  warn "theme has no xfwm4/ — falling back to Kali-Dark for window borders"
  XFWM_THEME="Kali-Dark"
fi

ICONS="Papirus-Dark"
UIFONT="JetBrainsMono Nerd Font 10"

# --- appearance ------------------------------------------------------------
step "appearance"
xset xsettings /Net/ThemeName          string "$THEME"
xset xsettings /Net/IconThemeName      string "$ICONS"
xset xsettings /Gtk/FontName           string "$UIFONT"
xset xsettings /Gtk/MonospaceFontName  string "$UIFONT"
xset xsettings /Net/EnableEventSounds  bool   false

step "window manager"
xset xfwm4 /general/theme            string "$XFWM_THEME"
xset xfwm4 /general/title_font       string "JetBrainsMono Nerd Font Bold 10"
xset xfwm4 /general/use_compositing  bool   true
# Modest compositing only. This guest runs on virtio video; shadows are cheap,
# heavy transparency is not.
xset xfwm4 /general/frame_opacity     int  100
xset xfwm4 /general/show_frame_shadow bool true

# Match the GTK config files to what xfconf now says, so applications started
# outside the session (and the greeter) agree with the desktop.
step "gtk config files"
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=$ICONS
gtk-font-name=$UIFONT
gtk-application-prefer-dark-theme=1
EOF
printf 'gtk-theme-name="%s"\ngtk-icon-theme-name="%s"\ngtk-font-name="%s"\n' \
  "$THEME" "$ICONS" "$UIFONT" > "$HOME/.gtkrc-2.0"
if [ -d "$THEME_DIR/gtk-4.0" ]; then
  ln -sfn "$THEME_DIR/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
fi
ok "gtk-2/3/4 config written for $THEME"

# --- panels ----------------------------------------------------------------
step "panel backup"
BACKUP="$HOME/.rice-backup/panel-$(date +%Y%m%d-%H%M%S).tar.bz2"
mkdir -p "$(dirname "$BACKUP")"
if have xfce4-panel-profiles; then
  xfce4-panel-profiles save "$BACKUP" >/dev/null 2>&1 \
    && ok "saved current panel layout to ${BACKUP#"$HOME"/}" \
    || warn "could not save a panel profile — continuing"
else
  warn "xfce4-panel-profiles not installed; no panel backup"
fi

step "top panel"
# Kali's stock panel-1 keeps the menu, tray, clock and the HTB indicator.
xset xfce4-panel /panels/panel-1/position-locked bool false
xset xfce4-panel /panels/panel-1/size           uint 30

step "bottom taskbar"
# A second panel holding nothing but window buttons — one button per open
# window, with its title, across the bottom. This is the piece i3 could not
# provide: its tab bar is a property of a container, not a task list.
TASKLIST_ID=50
xset xfce4-panel /plugins/plugin-$TASKLIST_ID                        string tasklist
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/grouping               bool   false
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/show-labels            bool   true
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/include-all-workspaces bool   true
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/flat-buttons           bool   false
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/window-scrolling       bool   false
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/show-handle            bool   false
xset xfce4-panel /plugins/plugin-$TASKLIST_ID/sort-order             uint   0

# p=8 is the bottom-centre snap position. position-locked stays false so the
# panel can simply be dragged if it lands somewhere unexpected.
xset xfce4-panel /panels/panel-2/position        string "p=8;x=0;y=0"
xset xfce4-panel /panels/panel-2/length          uint   100
xset xfce4-panel /panels/panel-2/size            uint   34
xset xfce4-panel /panels/panel-2/icon-size       uint   20
xset xfce4-panel /panels/panel-2/position-locked bool   false
xset xfce4-panel /panels/panel-2/nrows           uint   1
xset xfce4-panel /panels/panel-2/enter-opacity   uint   100
xset xfce4-panel /panels/panel-2/leave-opacity   uint   100

xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids \
  -t int -s "$TASKLIST_ID" --force-array --create >/dev/null 2>&1 \
  || die "failed to attach the tasklist to panel-2"
ok "panel-2 holds the tasklist"

# Register both panels. Doing this last means a failure above leaves the
# original single-panel layout untouched.
xfconf-query -c xfce4-panel -p /panels -t int -s 1 -t int -s 2 --force-array \
  >/dev/null 2>&1 || die "failed to register panel-2"
ok "two panels registered"

step "panel colours"
# Catppuccin crust #11111b as a solid background on both panels.
for p in panel-1 panel-2; do
  xfconf-query -c xfce4-panel -p "/panels/$p/background-style" --create -t int -s 1 >/dev/null 2>&1
  xfconf-query -c xfce4-panel -p "/panels/$p/background-rgba" --force-array --create \
    -t double -s 0.0667 -t double -s 0.0667 -t double -s 0.1059 -t double -s 1.0 \
    >/dev/null 2>&1
done
ok "panels set to Mocha crust"

# --- wallpaper -------------------------------------------------------------
step "wallpaper"
WALL=""
for c in "$HOME/.local/share/wallpapers"/default.* ; do [ -f "$c" ] && { WALL="$c"; break; }; done
[ -z "$WALL" ] && WALL=$(find "$HOME/.local/share/wallpapers" -maxdepth 1 -type f \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | sort | head -1)

if [ -n "$WALL" ]; then
  # Monitor names vary (Virtual-1, Virtual1, ...), so set every backdrop
  # property the desktop actually declares rather than guessing one.
  n=0
  while read -r prop; do
    [ -n "$prop" ] || continue
    xfconf-query -c xfce4-desktop -p "$prop" --create -t string -s "$WALL" >/dev/null 2>&1 && n=$((n+1))
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$')
  if [ "$n" -gt 0 ]; then
    ok "wallpaper set on $n backdrop(s): $(basename "$WALL")"
  else
    warn "no backdrop properties found — set the wallpaper by right-clicking the desktop"
  fi
else
  warn "no wallpaper in ~/.local/share/wallpapers"
fi

# --- restart ---------------------------------------------------------------
step "applying"
xfce4-panel -r >/dev/null 2>&1 && ok "panel restarted" || warn "panel restart failed — log out and back in"
xfwm4 --replace >/dev/null 2>&1 &
sleep 1
ok "window manager reloaded"

printf '\n'
warn "One manual step left — the HTB indicator."
cat <<'EOF'
  xfconf cannot add a Generic Monitor plugin reliably, so add it by hand once:

    right-click the top panel -> Panel -> Add New Items...
    pick "Generic Monitor" -> Add
    right-click the new item -> Properties
      Command: htb-genmon
      Period:  2 seconds
      Label:   (clear it)

  It renders VPN state, current box and current target, and shows nothing
  but "vpn down" until you set them.
EOF
