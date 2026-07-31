# shellcheck shell=bash
# Link dotfiles into $HOME. Anything real that is in the way gets moved to
# ~/.rice-backup/<timestamp>/ first — nothing is ever deleted.
#
# Directories we own wholesale are linked as directories. Everything else is
# linked file-by-file so we never take over a directory shared with other
# packages (~/.config in particular).

DF="$RICE_ROOT/dotfiles"

step "config directories"
# These are fully ours, so linking the whole directory is safe.
#
# i3, polybar and picom moved to legacy/ when the desktop switched to XFCE
# and are deliberately not linked. rofi, dunst and kitty are window-manager
# agnostic and still earn their place — rofi as a launcher bound to a key,
# dunst only if you prefer it to xfce4-notifyd.
for d in rofi kitty; do
  link_file "$DF/.config/$d" "$HOME/.config/$d"
done

# dunst duplicates xfce4-notifyd, which XFCE starts on its own. Link it only
# if xfce4-notifyd is absent, otherwise two daemons race for notifications.
if pkg_installed xfce4-notifyd; then
  skip "xfce4-notifyd present — not linking dunst"
else
  link_file "$DF/.config/dunst" "$HOME/.config/dunst"
fi

step "individual files"
link_file "$DF/.config/starship.toml" "$HOME/.config/starship.toml"
link_file "$DF/.tmux.conf"            "$HOME/.tmux.conf"

step "session autostart"
# ~/.config/autostart is shared with everything else that autostarts, so link
# file-by-file, never the directory.
#
#   numlockx.desktop    the XFCE replacement for the i3 `exec numlockx on` —
#                       without it the numpad navigates instead of typing
#   autocutsel.desktop  re-owns the clipboard after every copy so prlcp can
#                       read it — kitty/xclip copies never reach macOS otherwise
for f in numlockx.desktop autocutsel.desktop; do
  link_file "$DF/.config/autostart/$f" "$HOME/.config/autostart/$f"
done

step "zsh"
# Kali ships a substantial default .zshrc. Rather than replace it wholesale,
# append a fenced block that sources ours — so Kali's defaults survive an
# upgrade and our config layers on top.
link_file "$DF/.zshrc.rice" "$HOME/.zshrc.rice"
ensure_block "$HOME/.zshrc" '[ -f "$HOME/.zshrc.rice" ] && source "$HOME/.zshrc.rice"'

step "executable bits"
# git preserves the +x bit, but a fresh checkout on a filesystem that does
# not (or an archive download) would not. Cheap to assert.
chmod +x "$RICE_ROOT"/bin/* "$RICE_ROOT"/bootstrap.sh "$RICE_ROOT"/tools/*.sh 2>/dev/null || true
ok "scripts are executable"
