# shellcheck shell=bash
# Shell: oh-my-zsh, plugins, starship. Mirrors the macOS host setup so
# muscle memory transfers between host and guest.

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$ZSH_DIR/custom"

step "oh-my-zsh"
if [ -d "$ZSH_DIR" ]; then
  skip "oh-my-zsh already installed"
else
  # Unattended: does not touch .zshrc and does not exec a new shell.
  # We manage .zshrc ourselves in 20-link.sh.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "oh-my-zsh installed"
fi

step "zsh plugins"
git_ensure https://github.com/zsh-users/zsh-autosuggestions \
           "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
git_ensure https://github.com/zsh-users/zsh-syntax-highlighting \
           "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
# Same Catppuccin highlighting theme the host runs, same directory name.
git_ensure https://github.com/catppuccin/zsh-syntax-highlighting \
           "$ZSH_CUSTOM_DIR/plugins/catppuccin-zsh-syntax-highlighting"

step "starship"
# Not packaged in Kali — the official installer is the supported path.
if have starship; then
  skip "starship $(starship --version | head -1 | awk '{print $2}') already installed"
else
  curl -fsSL https://starship.rs/install.sh | sudo sh -s -- --yes --bin-dir /usr/local/bin
  have starship && ok "starship installed" || die "starship install failed"
fi

step "default shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ]; then
  skip "zsh is already the login shell"
else
  sudo chsh -s "$(command -v zsh)" "$USER"
  ok "login shell set to zsh"
fi

step "tmux plugin manager"
git_ensure https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
