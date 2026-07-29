# shellcheck shell=bash
# GTK / Qt / greeter theming, so the desktop is coherent from login onward
# and Qt apps do not flash white against everything else.

GTK_THEME_NAME="Catppuccin-Mocha-Standard-Lavender-Dark"
THEME_DIR="$HOME/.local/share/themes"
ICON_THEME="Papirus-Dark"

step "Catppuccin GTK theme"
# Not packaged in Debian/Kali — it comes from the project's releases.
if [ -d "$THEME_DIR/$GTK_THEME_NAME" ]; then
  skip "$GTK_THEME_NAME already installed"
else
  mkdir -p "$THEME_DIR"
  GTK_VER="v1.0.3"
  GTK_URL="https://github.com/catppuccin/gtk/releases/download/${GTK_VER}/${GTK_THEME_NAME}.zip"
  tmp=$(mktemp -d)
  if curl -fsSL --retry 3 -o "$tmp/theme.zip" "$GTK_URL"; then
    unzip -qo "$tmp/theme.zip" -d "$THEME_DIR"
    ok "installed $GTK_THEME_NAME"
  else
    warn "could not download the Catppuccin GTK theme — GTK apps stay on the default"
    warn "grab it from https://github.com/catppuccin/gtk/releases and unzip into $THEME_DIR"
    GTK_THEME_NAME=""
  fi
  rm -rf "$tmp"
fi

step "GTK settings"
if [ -n "$GTK_THEME_NAME" ]; then
  mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME_NAME
gtk-icon-theme-name=$ICON_THEME
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF
  printf 'gtk-theme-name="%s"\ngtk-icon-theme-name="%s"\ngtk-font-name="JetBrainsMono Nerd Font 10"\n' \
    "$GTK_THEME_NAME" "$ICON_THEME" > "$HOME/.gtkrc-2.0"

  # GTK4 reads the theme from a linked gtk.css rather than settings.ini.
  if [ -d "$THEME_DIR/$GTK_THEME_NAME/gtk-4.0" ]; then
    ln -sfn "$THEME_DIR/$GTK_THEME_NAME/gtk-4.0/gtk.css"       "$HOME/.config/gtk-4.0/gtk.css"
    ln -sfn "$THEME_DIR/$GTK_THEME_NAME/gtk-4.0/gtk-dark.css"  "$HOME/.config/gtk-4.0/gtk-dark.css" 2>/dev/null || true
  fi
  ok "GTK 2/3/4 pointed at $GTK_THEME_NAME"

  # XFCE keeps its own copy of these; set them too so the fallback session
  # does not look broken when you drop back into it.
  if have xfconf-query; then
    xfconf-query -c xsettings -p /Net/ThemeName        -s "$GTK_THEME_NAME" 2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName    -s "$ICON_THEME" 2>/dev/null || true
    ok "XFCE fallback session themed to match"
  fi
fi

step "Qt settings"
# qterminal and other Qt apps ignore GTK entirely. Without this they render
# in the default light palette against an otherwise dark desktop.
mkdir -p "$HOME/.config/qt5ct" "$HOME/.config/qt6ct"
for v in qt5ct qt6ct; do
  cat > "$HOME/.config/$v/$v.conf" <<EOF
[Appearance]
style=Fusion
icon_theme=$ICON_THEME
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
if [ -f "$GREETER_CONF" ] && [ -n "$GTK_THEME_NAME" ]; then
  if sudo grep -q "^theme-name=$GTK_THEME_NAME" "$GREETER_CONF" 2>/dev/null; then
    skip "greeter already themed"
  else
    sudo cp "$GREETER_CONF" "${GREETER_CONF}.kali-rice.bak" 2>/dev/null || true
    # The greeter runs as its own user and cannot read ~/.local/share/themes,
    # so the theme has to exist system-wide as well.
    sudo mkdir -p /usr/share/themes
    sudo cp -rn "$THEME_DIR/$GTK_THEME_NAME" /usr/share/themes/ 2>/dev/null || true
    sudo sed -i \
      -e "s|^#\?theme-name=.*|theme-name=$GTK_THEME_NAME|" \
      -e "s|^#\?icon-theme-name=.*|icon-theme-name=$ICON_THEME|" \
      -e "s|^#\?font-name=.*|font-name=JetBrainsMono Nerd Font 10|" \
      "$GREETER_CONF"
    ok "greeter themed (backup at ${GREETER_CONF}.kali-rice.bak)"
  fi
else
  skip "no lightdm-gtk-greeter.conf — skipping greeter"
fi
