# shellcheck shell=bash
# Packages: the i3 desktop stack, CLI tooling, fonts, and x86_64 emulation.

apt_refresh_once

# Kali's own i3 spin. Pulls i3, polybar, picom, rofi, kitty, feh, flameshot,
# betterlockscreen, thunar, zathura, ranger and the i3-dotfiles package.
# XFCE is deliberately left installed — both sessions stay at the greeter.
step "desktop stack (kali-desktop-i3)"
apt_ensure kali-desktop-i3

step "desktop extras"
apt_ensure \
  polybar picom rofi feh dunst flameshot kitty \
  lxappearance papirus-icon-theme qt5ct qt6ct \
  maim xdotool xclip numlockx

step "CLI tooling"
apt_ensure \
  eza bat fd-find ripgrep fzf zoxide jq tmux zsh \
  curl wget unzip git build-essential

step "HTB support"
# seclists lands in /usr/share/seclists.
# qemu-user-binfmt registers the binfmt_misc handlers that let this aarch64
# box execute x86_64 ELFs directly. qemu-user-static is NOT in the arm64
# Kali repo — qemu-user-binfmt is the working equivalent here.
apt_ensure seclists openvpn qemu-user-binfmt

step "memory headroom"
# The host is 8 GB and already paging with this VM at 4 GB. zram buys
# compressed swap inside the guest rather than taking more from the host.
apt_ensure zram-tools

if [ -f /etc/default/zramswap ]; then
  if grep -qE '^\s*PERCENT\s*=\s*50\b' /etc/default/zramswap; then
    skip "zramswap already at 50%"
  else
    sudo sed -i 's/^#\?\s*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
    grep -qE '^PERCENT=' /etc/default/zramswap || echo 'PERCENT=50' | sudo tee -a /etc/default/zramswap >/dev/null
    sudo systemctl restart zramswap 2>/dev/null || true
    ok "zramswap set to 50% and restarted"
  fi
fi
sudo systemctl enable zramswap >/dev/null 2>&1 || true

# --- fonts -----------------------------------------------------------------
# The Debian fonts-jetbrains-mono package is the UNPATCHED upstream font. It
# has no Nerd Font glyphs, so polybar and starship render tofu boxes with it.
# The patched build has to come from the Nerd Fonts release.
step "JetBrainsMono Nerd Font"
FONT_DIR="$HOME/.local/share/fonts"
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
  skip "JetBrainsMono Nerd Font already present"
else
  NF_VER="v3.4.0"
  NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VER}/JetBrainsMono.tar.xz"
  tmp=$(mktemp -d)
  if curl -fsSL --retry 3 -o "$tmp/JetBrainsMono.tar.xz" "$NF_URL"; then
    mkdir -p "$FONT_DIR/JetBrainsMonoNerdFont"
    tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$FONT_DIR/JetBrainsMonoNerdFont"
    fc-cache -f "$FONT_DIR" >/dev/null
    ok "installed JetBrainsMono Nerd Font $NF_VER"
  else
    warn "could not download Nerd Font — polybar/starship glyphs will show as boxes"
    warn "install manually from https://github.com/ryanoasis/nerd-fonts/releases"
  fi
  rm -rf "$tmp"
fi

# Kali names the ripgrep-adjacent binaries differently to avoid collisions.
# Symlink the conventional names into ~/.local/bin so muscle memory works.
mkdir -p "$HOME/.local/bin"
if have fdfind && ! have fd; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; ok "fd -> fdfind"
fi
if have batcat && ! have bat; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; ok "bat -> batcat"
fi
