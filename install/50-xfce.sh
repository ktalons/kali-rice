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
# xfset and xfconf_session_ready live in install/lib.sh — 60-keys.sh needs
# them too, and a step has to work when run on its own (./bootstrap.sh 60).
xfconf_session_ready || return 0

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

# An xfwm4 theme is its image assets, not its directory. catppuccin/gtk ships
# an xfwm4/ folder containing nothing but a 380-byte themerc — no PNGs for
# borders, corners or buttons. Point xfwm4 at it and you get a window manager
# that draws no title bar and no borders at all, so windows cannot be dragged
# or resized. Nothing errors; the desktop just quietly becomes unusable.
#
# So count the assets. A real theme has ~48 files; anything under 20 is a stub.
XFWM_ASSETS=0
if [ -d "$THEME_DIR/xfwm4" ]; then
  XFWM_ASSETS=$(find "$THEME_DIR/xfwm4" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.xpm' \) 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$XFWM_ASSETS" -ge 20 ]; then
  XFWM_THEME="$THEME"
  ok "theme has $XFWM_ASSETS xfwm4 assets — window borders themed to match"
else
  XFWM_THEME="Kali-Dark"
  warn "$THEME has only $XFWM_ASSETS xfwm4 image assets — that is a stub, not a theme."
  warn "Using Kali-Dark for window borders instead; a border-less xfwm4 leaves"
  warn "windows that cannot be moved or resized."
  warn "For matching borders, install a real one: https://github.com/catppuccin/xfwm4"
fi

ICONS="Papirus-Dark"
UIFONT="JetBrainsMono Nerd Font 10"

# --- appearance ------------------------------------------------------------
step "appearance"
xfset xsettings /Net/ThemeName          string "$THEME"
xfset xsettings /Net/IconThemeName      string "$ICONS"
xfset xsettings /Gtk/FontName           string "$UIFONT"
xfset xsettings /Gtk/MonospaceFontName  string "$UIFONT"
xfset xsettings /Net/EnableEventSounds  bool   false

step "window manager"
xfset xfwm4 /general/theme            string "$XFWM_THEME"
xfset xfwm4 /general/title_font       string "JetBrainsMono Nerd Font Bold 10"
xfset xfwm4 /general/use_compositing  bool   true
# Modest compositing only. This guest runs on virtio video; shadows are cheap,
# heavy transparency is not.
xfset xfwm4 /general/frame_opacity     int  100
xfset xfwm4 /general/show_frame_shadow bool true

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
xfset xfce4-panel /panels/panel-1/position-locked bool false
xfset xfce4-panel /panels/panel-1/size           uint 30

step "bottom taskbar"
# A second panel holding nothing but window buttons — one button per open
# window, with its title, across the bottom. This is the piece i3 could not
# provide: its tab bar is a property of a container, not a task list.
TASKLIST_ID=50
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID                        string tasklist
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/grouping               bool   false
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/show-labels            bool   true
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/include-all-workspaces bool   true
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/flat-buttons           bool   false
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/window-scrolling       bool   false
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/show-handle            bool   false
xfset xfce4-panel /plugins/plugin-$TASKLIST_ID/sort-order             uint   0

# p=8 is the bottom-centre snap position. position-locked stays false so the
# panel can simply be dragged if it lands somewhere unexpected.
xfset xfce4-panel /panels/panel-2/position        string "p=8;x=0;y=0"
xfset xfce4-panel /panels/panel-2/length          uint   100
xfset xfce4-panel /panels/panel-2/size            uint   34
xfset xfce4-panel /panels/panel-2/icon-size       uint   20
xfset xfce4-panel /panels/panel-2/position-locked bool   false
xfset xfce4-panel /panels/panel-2/nrows           uint   1
xfset xfce4-panel /panels/panel-2/enter-opacity   uint   100
xfset xfce4-panel /panels/panel-2/leave-opacity   uint   100

xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids \
  -t int -s "$TASKLIST_ID" --force-array --create >/dev/null 2>&1 \
  || die "failed to attach the tasklist to panel-2"
ok "panel-2 holds the tasklist"

# Register both panels. Doing this last means a failure above leaves the
# original single-panel layout untouched.
xfconf-query -c xfce4-panel -p /panels -t int -s 1 -t int -s 2 --force-array \
  >/dev/null 2>&1 || die "failed to register panel-2"
ok "two panels registered"

step "clipboard history"
# Clipman keeps a scrollback of everything copied — the thing you want when
# an IP, a hash and a password are all in flight on the same box.
#
# panel-1 is NOT rebuilt here. It already holds Kali's menu, tray and clock
# plus the hand-added genmon, and writing a fresh plugin-ids array would wipe
# every one of them. Read the array, append, write it back — and if the read
# comes back empty, do nothing at all rather than guess.
if ! pkg_installed xfce4-clipman-plugin; then
  warn "xfce4-clipman-plugin not installed — run ./bootstrap.sh 00 first"
else
  # Reuse an existing clipman plugin if one is already in the layout,
  # otherwise take the first free id from 51 up. Never assume an id is free:
  # clobbering /plugins/plugin-N silently replaces whatever plugin N was.
  CLIPMAN_ID=""
  USED_IDS=$(xfconf-query -c xfce4-panel -l 2>/dev/null \
    | sed -n 's|^/plugins/plugin-\([0-9]\{1,\}\)$|\1|p' | sort -n)
  for id in $USED_IDS; do
    if [ "$(xfconf-query -c xfce4-panel -p "/plugins/plugin-$id" 2>/dev/null)" = "clipman" ]; then
      CLIPMAN_ID="$id"; break
    fi
  done
  if [ -z "$CLIPMAN_ID" ]; then
    CLIPMAN_ID=51
    while printf '%s\n' "$USED_IDS" | grep -qx "$CLIPMAN_ID"; do
      CLIPMAN_ID=$((CLIPMAN_ID + 1))
    done
  fi

  xfset xfce4-panel /plugins/plugin-$CLIPMAN_ID string clipman

  # Text only. Clipman's image history holds every screenshot in RAM, and
  # htb-shot is bound to Print — that adds up fast in a 4 GB guest.
  xfset xfce4-panel /plugins/plugin-$CLIPMAN_ID/add-primary-clipboard bool false
  xfset xfce4-panel /plugins/plugin-$CLIPMAN_ID/save-on-quit          bool false
  xfset xfce4-panel /plugins/plugin-$CLIPMAN_ID/max-texts-in-history  uint 30
  xfset xfce4-panel /plugins/plugin-$CLIPMAN_ID/max-images-in-history uint 0

  # add-primary-clipboard stays false deliberately: kitty is set to
  # copy_on_select, so mirroring PRIMARY into the history would record every
  # mouse drag, and it is also the selection autocutsel is kept away from.
  P1_IDS=$(xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids 2>/dev/null \
    | sed -n 's/^\([0-9]\{1,\}\)$/\1/p')
  if [ -z "$P1_IDS" ]; then
    warn "could not read panel-1's plugin list — not touching it."
    warn "Add clipman by hand: right-click the top panel -> Panel -> Add New Items..."
  elif printf '%s\n' "$P1_IDS" | grep -qx "$CLIPMAN_ID"; then
    skip "clipman (plugin-$CLIPMAN_ID) already on panel-1"
  else
    SET_ARGS=()
    for id in $P1_IDS; do SET_ARGS+=(-t int -s "$id"); done
    SET_ARGS+=(-t int -s "$CLIPMAN_ID")
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids \
      --force-array --create "${SET_ARGS[@]}" >/dev/null 2>&1 \
      || die "failed to append clipman to panel-1"
    ok "clipman appended to panel-1 as plugin-$CLIPMAN_ID (kept $(printf '%s\n' "$P1_IDS" | wc -l | tr -d ' ') existing plugins)"
  fi
fi

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
    xfconf-query -c xfce4-desktop -p "$prop" --create -t string -s "$WALL" >/dev/null 2>&1 || continue
    n=$((n+1))
    # Setting the image without the style leaves it at whatever the backdrop
    # was already on — usually centred at native size, which on a 1-to-1
    # wallpaper shows a small rectangle in a corner. 5 = zoomed to fill.
    xfconf-query -c xfce4-desktop -p "${prop%last-image}image-style" \
      --create -t int -s 5 >/dev/null 2>&1 || true
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$')
  if [ "$n" -gt 0 ]; then
    ok "wallpaper set + zoomed on $n backdrop(s): $(basename "$WALL")"
  else
    warn "no backdrop properties found — set the wallpaper by right-clicking the desktop"
  fi
else
  warn "no wallpaper in ~/.local/share/wallpapers"
fi

# --- restart ---------------------------------------------------------------
step "applying"
xfce4-panel -r >/dev/null 2>&1 && ok "panel restarted" || warn "panel restart failed — log out and back in"
# Deliberately no `xfwm4 --replace`. xfwm4 watches xfconf and picks up theme
# changes live, so a restart buys nothing — and backgrounding it from an
# install script makes the window manager a child of that script, which dies
# with it and leaves the session with no WM at all.
ok "xfwm4 picks up theme changes from xfconf on its own"

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
