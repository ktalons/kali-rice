# shellcheck shell=bash
# Link dotfiles into $HOME. Anything real that is in the way gets moved to
# ~/.rice-backup/<timestamp>/ first — nothing is ever deleted.
#
# Directories we own wholesale are linked as directories. Everything else is
# linked file-by-file so we never take over a directory shared with other
# packages (~/.config in particular).

DF="$RICE_ROOT/dotfiles"

step "config directories"
# These are fully ours. Linking the whole directory is what cleanly
# supersedes the configs Kali's i3-dotfiles package ships.
for d in i3 polybar picom rofi dunst kitty; do
  link_file "$DF/.config/$d" "$HOME/.config/$d"
done

step "individual files"
link_file "$DF/.config/starship.toml" "$HOME/.config/starship.toml"
link_file "$DF/.tmux.conf"            "$HOME/.tmux.conf"

step "zsh"
# Kali ships a substantial default .zshrc. Rather than replace it wholesale,
# append a fenced block that sources ours — so Kali's defaults survive an
# upgrade and our config layers on top.
link_file "$DF/.zshrc.rice" "$HOME/.zshrc.rice"
ensure_block "$HOME/.zshrc" '[ -f "$HOME/.zshrc.rice" ] && source "$HOME/.zshrc.rice"'

step "executable bits"
# git preserves the +x bit, but a fresh checkout on a filesystem that does
# not (or an archive download) would not. Cheap to assert.
chmod +x "$RICE_ROOT"/bin/* "$RICE_ROOT"/bootstrap.sh 2>/dev/null || true
chmod +x "$DF"/.config/polybar/*.sh "$DF"/.config/polybar/scripts/*.sh 2>/dev/null || true
ok "scripts are executable"
