# shellcheck shell=bash
# Theme prerequisites that are not XFCE-specific: fetch the Catppuccin GTK
# theme, point Qt at a matching palette, and theme the greeter.
#
# GTK settings and every xfconf property are set by 50-xfce.sh, which runs
# inside a live session and verifies each one. They are deliberately not
# duplicated here.

ICONS="Papirus-Dark"
UIFONT="JetBrainsMono Nerd Font 10"
THEME_DIR="$HOME/.local/share/themes"

# Find an installed Catppuccin Mocha theme by pattern, never by a fixed name.
# catppuccin/gtk has renamed its release assets more than once
# (Catppuccin-Mocha-Standard-Lavender-Dark -> catppuccin-mocha-mauve-standard+default);
# a hardcoded name that no longer matches is how this silently did nothing
# for a whole install.
find_theme() {
  local d
  for d in "$THEME_DIR"/*atppuccin*[Mm]ocha* /usr/share/themes/*atppuccin*[Mm]ocha*; do
    [ -d "$d" ] || continue
    case "$d" in *hdpi*) continue ;; esac
    basename "$d"; return 0
  done
  return 1
}

step "Catppuccin GTK theme"
if THEME=$(find_theme); then
  ok "found $THEME"
else
  mkdir -p "$THEME_DIR"
  warn "no Catppuccin Mocha theme installed."
  warn "Release asset names change between versions, so this is not downloaded"
  warn "automatically — grabbing a guessed URL is how you get a silent 404."
  warn ""
  warn "  1. https://github.com/catppuccin/gtk/releases"
  warn "  2. download a *mocha*standard* zip for your accent"
  warn "  3. unzip -d $THEME_DIR"
  warn "  4. re-run: ./bootstrap.sh 30 50"
  THEME=""
fi

step "Qt palette"
# Qt applications ignore GTK theming entirely. Without this they render in
# the default light palette against an otherwise dark desktop.
apt_ensure qt5ct qt6ct >/dev/null 2>&1 || true
mkdir -p "$HOME/.config/qt5ct" "$HOME/.config/qt6ct"
for v in qt5ct qt6ct; do
  cat > "$HOME/.config/$v/$v.conf" <<EOF
[Appearance]
style=Fusion
icon_theme=$ICONS
standard_dialogs=default

[Fonts]
general="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
EOF
done
ensure_block "$HOME/.profile" 'export QT_QPA_PLATFORMTHEME=qt5ct'
ok "Qt pointed at qt5ct/qt6ct"

step "lightdm greeter"
GREETER_CONF=/etc/lightdm/lightdm-gtk-greeter.conf
if [ -z "$THEME" ]; then
  skip "no theme to apply — skipping greeter"
elif [ ! -f "$GREETER_CONF" ]; then
  skip "no lightdm-gtk-greeter.conf present"
elif sudo grep -q "^theme-name=$THEME\$" "$GREETER_CONF" 2>/dev/null; then
  skip "greeter already themed"
else
  sudo cp -n "$GREETER_CONF" "${GREETER_CONF}.kali-rice.bak" 2>/dev/null || true
  # The greeter runs as the lightdm user and cannot read your ~/.local, so
  # the theme has to exist system-wide as well.
  if [ -d "$THEME_DIR/$THEME" ]; then
    sudo mkdir -p /usr/share/themes
    sudo cp -rn "$THEME_DIR/$THEME" /usr/share/themes/ 2>/dev/null || true
  fi
  sudo sed -i \
    -e "s|^#\?theme-name=.*|theme-name=$THEME|" \
    -e "s|^#\?icon-theme-name=.*|icon-theme-name=$ICONS|" \
    -e "s|^#\?font-name=.*|font-name=$UIFONT|" \
    "$GREETER_CONF"
  if sudo grep -q "^theme-name=$THEME\$" "$GREETER_CONF"; then
    ok "greeter themed (backup at ${GREETER_CONF}.kali-rice.bak)"
  else
    warn "greeter edit did not take — check $GREETER_CONF by hand"
  fi
fi
