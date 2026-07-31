# kali-rice

A Catppuccin Mocha XFCE setup for a Kali VM used for Hack The Box, with the
HTB workflow wired into the desktop instead of bolted beside it.

Built for **Kali on aarch64 under Parallels on Apple Silicon**, which is a
constrained enough target that several decisions here only make sense in that
context. Read the caveats before running it on anything else.

> This started as an i3 tiling rice and that was dropped after using it — the
> tiling model was the problem, not the config. Those files are preserved in
> [`legacy/`](legacy/README.md) with the full reasoning.

## What you get

**The desktop.** XFCE themed Catppuccin Mocha end to end: GTK 2/3/4, Qt,
xfwm4 window borders, both panels, the icon theme, and the lightdm greeter.
One app per screen, normal draggable windows, and a **bottom taskbar with one
button per open window** — click to switch.

**The indicator.** A single Generic Monitor item in the top panel carrying the
whole HTB state, rendering nothing until there is something to show:

| Shows | Source |
|---|---|
| `tun0` interface + IP, or `vpn down` | read from the kernel every refresh, never cached |
| the box you are currently on | `~/.htb/box` |
| the IP you are pointed at | `~/.htb/target` |

**The shell.** zsh + oh-my-zsh + starship, mirroring a macOS host setup so
muscle memory carries across. The starship prompt shows the current box and
target inline. tmux gets the same treatment, with the VPN IP in the status
line so a reattached session still tells you where you are.

**The keyboard.** The launcher and HTB bindings the i3 rice had, restored as
XFCE shortcuts. `Super` is the Command key under Parallels.

| Key | Does |
|---|---|
| `Super`+`Return` | kitty |
| `Super`+`D` / `Super`+`Space` | rofi, app launcher |
| `Super`+`Shift`+`D` | rofi, run a command |
| `Super`+`W` | rofi, switch window |
| `Super`+`E` / `Super`+`B` | thunar / firefox |
| `Print` / `Shift`+`Print` | screenshot region / full screen, into the current box |
| `Super`+`T` | prompt for a target and set it |
| `Super`+`Shift`+`B` | prompt for a box and open it |
| `Super`+`V` | VPN status in a terminal |
| `Super`+`Q` / `Super`+`F` | close window / fullscreen |
| `Super`+`1`–`4` | workspace |

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

## Install

```sh
git clone https://github.com/ktalons/kali-rice.git ~/Projects/kali-rice
cd ~/Projects/kali-rice
./bootstrap.sh
```

**Steps `50` and `60` must run from inside a live XFCE session.**
`xfconf-query` talks to `xfconfd` over the session bus; from a TTY, from
another window manager, or over `prlctl` there is nothing to talk to and every
setting is silently discarded. Both steps detect this, refuse to run, and say
so loudly in the final summary rather than reporting success. If they skipped:

```sh
# log into XFCE at the greeter first, then in a terminal there:
./bootstrap.sh 50 60
```

One manual step remains by design — adding the HTB indicator. xfconf cannot
add a panel plugin reliably, so:

> right-click the top panel → Panel → Add New Items… → **Generic Monitor**
> then right-click it → Properties → Command `htb-genmon`, Period `2`, clear the Label

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
- **Clipboard needs a bridge to actually cross over.** prlcp, the Tools
  clipboard daemon, transfers copies made in GTK apps (xfce4-terminal,
  Firefox) but not copies owned by kitty or xclip — those work inside the
  guest and silently never reach macOS. `autocutsel` autostarts with the
  session and re-owns the clipboard after every copy, so prlcp always has an
  owner it can read from. If copies stop crossing over, check
  `pgrep -a autocutsel` before blaming kitty.
- **NumLock is off until something turns it on.** Mac keyboards have no
  NumLock key, so the numpad navigates instead of typing digits. `numlockx on`
  runs from a lightdm drop-in at the greeter and again as a session autostart
  entry.
- **Kitty renders through OpenGL.** With 3D acceleration off it falls back to
  `llvmpipe` software rendering — usable, not snappy. Check with
  `glxinfo -B | grep -i "OpenGL renderer"` (`sudo apt install mesa-utils`). If
  you are on llvmpipe, either enable 3D acceleration on the VM or use
  `xfce4-terminal`, which is GTK/cairo and needs no GPU.
- **XFCE's own compositor is enabled**, with shadows but no heavy transparency
  — this guest is on virtio video. Turn it off entirely in Settings → Window
  Manager Tweaks → Compositor if anything feels sluggish.
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
  00-packages.sh      XFCE stack, panel plugins, CLI tools, Nerd Font,
                      qemu-user-binfmt, zram
  05-parallels.sh     Guest Tools prerequisites (dkms, headers, libfuse.so.2)
  10-shell.sh         oh-my-zsh, plugins, starship, tpm
  20-link.sh          backup-then-symlink into $HOME
  30-theme.sh         Catppuccin discovery, Qt palette, greeter
  40-htb.sh           ~/htb scaffold, commands on PATH, binfmt, wallpaper
  50-xfce.sh          xfconf theming, bottom taskbar  [needs a live session]
  60-keys.sh          launcher + HTB keyboard shortcuts
                                                      [needs a live session]
dotfiles/             mirrors $HOME (rofi, kitty, starship, tmux, zsh, autostart)
bin/                  htb-vpn, htb-box, htb-target, htb-shot, htb-genmon
legacy/               the dropped i3 rice — see legacy/README.md
tools/
  check-glyphs.sh     asserts every Nerd Font icon exists and is covered
```

## Checking the icons

Two things make a missing icon, and neither reports an error: a glyph getting
dropped from a config during editing, and the font that supplies it not being
installed (the panel silently substitutes DejaVu Sans, which has no Nerd Font
coverage at all, and reports nothing wrong). Both
look identical on screen — a gap where an icon should be.

```sh
tools/check-glyphs.sh
```

It asserts a per-file glyph count and then checks every codepoint the repo
uses against the installed font. Run it after editing any config that carries
icons.

## A theme is its assets, not its directory

`catppuccin/gtk` ships an `xfwm4/` folder containing nothing but a 380-byte
`themerc` — no PNGs for borders, corners or buttons. Point xfwm4 at it and you
get a window manager that draws no title bar and no borders, so **windows
cannot be moved or resized**. Nothing errors; the desktop just quietly becomes
unusable, and it looks like the window manager crashed.

`50-xfce.sh` therefore counts image assets rather than testing for the
directory, and falls back to `Kali-Dark` below 20. If it lands on the fallback
and you want matching borders, install a real one from
[catppuccin/xfwm4](https://github.com/catppuccin/xfwm4).

Instant fix if you ever end up with undraggable windows:

```sh
xfconf-query -c xfwm4 -p /general/theme -s Kali-Dark
```

## `override` means "custom is the whole list"

XFCE keeps shortcuts in two trees per base — `/commands/default/<key>` and
`/commands/custom/<key>` — and the custom tree only takes effect once
`/commands/custom/override` is `true`.

The trap is what that flag means. It is not "prefer custom where it exists",
it is **"custom is the complete list"**. Flip it on a profile whose custom
tree holds only your own three bindings and every stock shortcut that is not
in it disappears: the lock screen, the run dialog, the display switcher.
Nothing errors, and the keys you did set work perfectly, so it reads as a
success.

`60-keys.sh` therefore copies every default into the custom tree first and
only then sets `override`, which is exactly what the Settings dialog does.
The previous set is dumped to `~/.rice-backup/keyboard-shortcuts-<stamp>.txt`
before anything is touched.

The same file also unbinds collisions before claiming a key, because xfwm4
grabs keys ahead of the command shortcuts — with `<Super>D` still on
show-desktop, binding it to rofi looks like rofi is broken. And because XFCE
matches shortcuts by parsing the property name rather than comparing it,
`<Super><Shift>b` and `<Shift><Super>b` are one shortcut stored under two
properties, both live and fighting. Collisions are matched on the modifier
set plus the keysym, not on spelling.

## Licence

MIT.
