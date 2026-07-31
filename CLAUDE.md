# kali-rice — project rules

Target is Kali rolling on aarch64 under Parallels on Apple Silicon. Kali rolling
tracks Debian **testing** (currently *forky*), not stable. That single fact is
behind most of the package surprises in this repo, including the one below.

## Parallels Tools will not install: `libfuse2` has no installation candidate

Symptom, from the Tools installer:

```
Package libfuse2 is not available, but is referred to by another package.
E: Package 'libfuse2' has no installation candidate
m libfuse2
Error: failed to install mandatory packages.
Error: failed to install or upgrade Parallels Guest Tools!
```

**Root cause.** fuse 2.x is EOL and was removed from Debian testing. The
time64 rename means `libfuse2` became `libfuse2t64`, but that package exists
only in **trixie** and **sid**, not forky. So on Kali rolling neither name
resolves. Renaming `libfuse2` to `libfuse2t64` inside the installer does not
help; the library is genuinely absent from the archive.

**What actually depends on it.** Exactly one shipped binary, `prl_fsd`, the
shared-folders daemon. Verified by scanning `tools/tools-arm64/` on the Tools
ISO. `prlcp` (clipboard), `prldnd` (drag and drop), `prltoolsd`, `prltimesync`
and `prl_nettool` have no fuse linkage. The dependency gates shared folders
only, but the installer treats it as mandatory for the whole product, so
everything fails together.

**Fix.** Pull the library from Debian trixie before running the installer:

```bash
cd /tmp
wget http://ftp.us.debian.org/debian/pool/main/f/fuse/libfuse2t64_2.9.9-9_arm64.deb
echo "c92aa3f45505aa5fbc4495e621e76edbfbfdd5ea33e90fd9c977b8b3b8df6543  libfuse2t64_2.9.9-9_arm64.deb" | sha256sum -c -
sudo dpkg -i libfuse2t64_2.9.9-9_arm64.deb
ldconfig -p | grep libfuse.so.2      # the gate. must print a hit.
sudo apt install -y dkms build-essential "linux-headers-$(uname -r)"
sudo "/media/$USER/Parallels Tools/install"
```

Its only dependency is `libc6 (>= 2.38)`. It declares `Conflicts: fuse (<< 2.9.9-9)`
and `libfuse2 (<< 2.9.9-9)`, both moot here since neither is installed.
`/usr/bin/fusermount` on this box does not come from the `fuse` package.

**Why this beats patching the installer.** The Tools ISO is read only and
Parallels re-mounts a fresh copy on every version bump, so any edit to
`installer/pm.sh` evaporates the next time Tools updates. This fix is state in
the guest. `pm.sh`'s `check_libfuse2()` tests for the shared object via
`ldconfig -p | grep -Fq 'libfuse.so.2'`, not for a package name, so once the
library is present the dependency is never added to the mandatory list again.

**Standing cost.** `libfuse2t64` is now a permanent foreign package: not in
Kali's archive, no security updates, shows as locally installed with no
candidate. It is an EOL leaf library read only by `prl_fsd` against the host's
own filesystem, so exposure is narrow, but do not let an aggressive
`apt autoremove --purge` or a dependency audit talk you into removing it.

*Diagnosed and fixed 2026-07-29 against Parallels Guest Tools 26.4.0.57513.*

## Fallback: skip shared folders instead

If pinning a trixie package is not acceptable, short-circuit the check. The ISO
is read only, so copy it out first:

```bash
mkdir -p ~/prl-tools
cp -a "/media/$USER/Parallels Tools/." ~/prl-tools/
chmod -R u+w ~/prl-tools
sed -i '120i\    return 0' ~/prl-tools/installer/pm.sh   # first line of check_libfuse2()
sed -n '118,123p' ~/prl-tools/installer/pm.sh            # confirm before running
sudo ~/prl-tools/install
```

Line 120 is correct for 26.4.0.57513 specifically. Everything installs;
`prl_fsd` then fails to start for lack of the library, so shared folders do not
work. This has to be redone on every Tools update.

## Two session gotchas left over from the i3 → XFCE move

**Numpad types nothing.** The i3 config ran `exec numlockx on`; the XFCE
session had no equivalent, so NumLock stayed off (Mac keyboards can't turn it
on) and the numpad sent Home/End/arrows. Fixed twice over: a lightdm drop-in
written by `00-packages.sh` (`/etc/lightdm/lightdm.conf.d/60-kali-rice-numlock.conf`)
turns it on at the greeter, and `~/.config/autostart/numlockx.desktop`
(linked by `20-link.sh`) re-asserts it per session.

**Copies from kitty and xclip never reach macOS.** prlcp transfers clipboard
contents owned by GTK apps but not by kitty or xclip — copy works inside the
guest and silently never crosses to the host, which also broke `htb-shot`'s
path-to-clipboard. `autocutsel -selection CLIPBOARD` (autostarted) re-owns
the clipboard after every copy so prlcp always reads from an owner it
understands. kitty's `copy_on_select clipboard` was never the problem; check
`pgrep -a autocutsel` before touching kitty.conf.

*Both diagnosed 2026-07-31; the numlock line and the clipboard behavior were
casualties of the desktop switch in commit 55a4063.*

## Keyboard shortcuts live in xfconf, and `override` is a loaded gun

`60-keys.sh` owns them. Three things about the
`xfce4-keyboard-shortcuts` channel that are not obvious and each of which
fails silently:

1. **`/<base>/custom/override` means "custom is the complete list"**, not
   "prefer custom". Setting it without first copying `/<base>/default/*` into
   `/<base>/custom/*` deletes every stock shortcut — xflock4, xfrun4, the
   display switcher — while the keys you did set work fine. `seed_custom()`
   copies first, then flips it, which is what the Settings dialog does.
2. **xfwm4 grabs keys before the command shortcuts see them.** A leftover WM
   binding on a key you want makes your command look like it never fires.
   XFCE ships `<Super>D` on show-desktop, which is exactly the key rofi
   wants. `free_key()` clears both bases before binding.
3. **The property name is a literal string but XFCE matches it by parsing**,
   so `<Super><Shift>b` and `<Shift><Super>b` are one shortcut stored twice,
   both live. `norm_key()` compares the modifier set plus keysym, treating
   `<Primary>`/`<Control>`/`<Ctrl>` and `<Mod1>`/`<Alt>` as the same thing.

The HTB keys bind `$HOME/.local/bin/htb-*` by absolute path on purpose.
Shortcuts are spawned by xfsettingsd with the *session* PATH, which comes
from the login shell and not from `.zshrc` — if `~/.local/bin` is not on it,
every HTB key does nothing and reports nothing.

Not restored from i3, deliberately: focus/move/split/resize (they drive a
tiling layout that no longer exists) and the `XF86Audio*` keys (xfsettingsd
already handles them).

## Run autocutsel on CLIPBOARD only

One instance, `-selection CLIPBOARD`. Do not add a second one bridging
PRIMARY: kitty runs `copy_on_select`, so every mouse drag already writes to
PRIMARY, and wiring the two selections together turns that into a feedback
loop where each selection keeps re-asserting the other.

## Clipboard history was tried and removed

`xfce4-clipman-plugin` was added in 1cba398 and taken back out in the commit
after — the plugin errored on this guest. autocutsel already solves the copy
-to-host problem, which was the part that actually mattered; the history was
a nice-to-have.

Removing the code was not enough on its own. The panel item and the
`<Super>c` binding are state in the *guest*, so anyone who ran the one
commit that shipped it would keep a broken plugin on the panel and a key
bound to a command that no longer resolves. `50-xfce.sh` detaches the plugin
and `60-keys.sh` unbinds the key, both idempotent and both silent once there
is nothing left to undo. Same reasoning as the libfuse fix above: a repo edit
does not reach a machine that already ran the old version.

The package is left installed if it is already there — pulling packages out
from under someone is not this repo's job. `sudo apt autoremove --purge
xfce4-clipman-plugin xfce4-clipman` if you want it gone.

## General

- Package availability questions get checked against **forky**, not trixie or
  bookworm. Assuming stable is how the wrong answer gets reached fast.
- A missing package is not always a rename. Check whether the source package
  was removed outright before hunting for a new name.
- See README "aarch64 caveats" and "Parallels notes" for the other constraints
  specific to this target.
