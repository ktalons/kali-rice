# kali-rice

An i3 + Catppuccin Mocha setup for a Kali VM used for Hack The Box, with the
HTB workflow wired into the desktop instead of bolted beside it.

Built for **Kali on aarch64 under Parallels on Apple Silicon**, which is a
constrained enough target that several decisions here only make sense in that
context. Read the caveats before running it on anything else.

## What you get

**The desktop.** i3 with gaps, Catppuccin Mocha across i3, polybar, rofi,
dunst, kitty, GTK 2/3/4, Qt, and the lightdm greeter. Workspaces are named for
how a box actually gets worked: `recon`, `shell`, `notes`, `web`, `burp`, with
Burp and Firefox auto-assigned.

**The bar.** Beyond the usual workspaces/CPU/clock, polybar carries three
modules that make this an HTB rice rather than a generic one:

| Module | Shows | Source |
|---|---|---|
| VPN | `tun0` interface + IP, or `vpn down` | read from the kernel every 3s, never cached |
| Box | the box you are currently on | `~/.htb/box` |
| Target | the IP you are pointed at | `~/.htb/target` |

**The shell.** zsh + oh-my-zsh + starship, mirroring a macOS host setup so
muscle memory carries across. The starship prompt shows the current box and
target inline. tmux gets the same treatment, with the VPN IP in the status
line so a reattached session still tells you where you are.

**The workflow.**

```
htb-vpn up               connect (finds the single .ovpn in ~/htb/vpn/)
htb-vpn status           what the kernel actually thinks
htb-vpn down             disconnect

htb-box cicada           scaffold ~/htb/boxes/cicada/, make it current,
                         open a 3-pane tmux layout in it
htb-box --list           every box, current one marked

htb-target 10.10.11.35            set the target
htb-target 10.10.11.35 cicada.htb set it and add a /etc/hosts entry
htb-target --clear                unset it, drop the hosts entry

htb-shot                 screenshot into the current box's screenshots/
```

Bound in i3: `Print` screenshots into the current box, `Super+t` prompts for a
target, `Super+Shift+b` prompts for a box, `Super+v` shows VPN status.

## Install

```sh
git clone https://github.com/ktalons/kali-rice.git ~/Projects/kali-rice
cd ~/Projects/kali-rice
./bootstrap.sh
```

Then log out and pick **i3** at the greeter.

`bootstrap.sh` is idempotent — run it as often as you like. A second run
changes nothing and prints mostly dimmed "already …" lines. Individual steps
can be run alone:

```sh
./bootstrap.sh --list
./bootstrap.sh 30 40     # just theming and HTB setup
```

**Nothing is deleted.** Anything real that a symlink would displace is moved
to `~/.rice-backup/<timestamp>/` first. XFCE is left installed and stays
selectable at the greeter, so there is always a way back.

## aarch64 caveats

This matters more than it sounds and is the thing most likely to bite you
mid-box.

- **`qemu-user-static` is not in the arm64 Kali repo.** `qemu-user-binfmt` is,
  and it is what `40-htb.sh` installs. It registers the `binfmt_misc` handlers
  that let this box execute x86_64 ELFs directly. Verify with
  `ls /proc/sys/fs/binfmt_misc/qemu-x86_64`.
- **Payloads for targets are unaffected.** `msfvenom` cross-compiles; the
  target's architecture is what matters, not yours.
- **Tooling shipped only as x86_64 Linux builds** needs either an arm64 build
  or qemu. `chisel`, `ligolo-ng` and friends publish arm64 releases — get the
  right one for local use and the target's architecture for the far side.
- **Pwn work is fiddly.** x86 `gdb`/`pwntools` under emulation works but is
  not the smooth path. Budget time for it or use an x86 box.

## Parallels notes

- **Guest Tools will not install on a stock Kali rolling.** It marks `libfuse2`
  mandatory, and fuse 2.x is gone from Debian testing, so neither `libfuse2` nor
  the time64 rename `libfuse2t64` resolves. `05-parallels.sh` supplies
  `libfuse.so.2` from Debian trixie ahead of time, which is what the installer
  actually checks for. Run `./bootstrap.sh 05` before mounting the Tools ISO.
  Full root cause and the fallback that skips shared folders are in `CLAUDE.md`.
- **Kitty renders through OpenGL.** With 3D acceleration off it falls back to
  `llvmpipe` software rendering — usable, not snappy. Check with
  `glxinfo -B | grep -i "OpenGL renderer"`. If you are on llvmpipe, either
  enable 3D acceleration on the VM or change `set $term` in the i3 config to
  `xfce4-terminal`.
- **Blur is off by default** in `picom.conf` for the same reason. There is a
  clearly marked block at the bottom of that file to turn it on once you have
  confirmed real acceleration.
- **`zram-tools` is installed and set to 50%.** On an 8 GB host running a 4 GB
  guest, compressed swap inside the guest is cheaper than taking more RAM from
  the host.

## What is deliberately not here

**No HTB content.** No writeups, no flags, no notes, no `.ovpn` files. HTB
permits publishing solutions only for Tier 0 modules, retired
Machines/Challenges/Sherlocks, and Starting Point — a per-file judgement call
is a standing risk for little return, so the surface is zero. `~/htb/` gets a
blanket `.gitignore` and this repo's `.gitignore` refuses the obvious
artefacts.

**No Neovim config.** Out of scope by choice; `vim` is there and untouched.

**No wallpapers of unknown provenance.** `40-htb.sh` copies personal
wallpapers from the Parallels shared folder at install time rather than
committing them here.

## Layout

```
bootstrap.sh          idempotent entrypoint
install/
  lib.sh              guards: pkg_installed, link_file, ensure_block, git_ensure
  00-packages.sh      i3 stack, CLI tools, Nerd Font, qemu-user-binfmt, zram
  05-parallels.sh     Guest Tools prerequisites (dkms, headers, libfuse.so.2)
  10-shell.sh         oh-my-zsh, plugins, starship, tpm
  20-link.sh          backup-then-symlink into $HOME
  30-theme.sh         GTK/Qt/greeter
  40-htb.sh           ~/htb scaffold, commands on PATH, binfmt, wallpaper
dotfiles/             mirrors $HOME
bin/                  htb-vpn, htb-box, htb-target, htb-shot, htb-lib.sh
```

## Licence

MIT.
