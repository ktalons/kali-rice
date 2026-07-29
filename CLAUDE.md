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

## General

- Package availability questions get checked against **forky**, not trixie or
  bookworm. Assuming stable is how the wrong answer gets reached fast.
- A missing package is not always a rename. Check whether the source package
  was removed outright before hunting for a new name.
- See README "aarch64 caveats" and "Parallels notes" for the other constraints
  specific to this target.
