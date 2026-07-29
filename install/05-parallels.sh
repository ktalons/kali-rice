# shellcheck shell=bash
# Parallels Guest Tools prerequisites.
#
# Does not install Tools itself — the ISO has to be mounted from the Parallels
# menu (Actions -> Install Parallels Tools) and the installer wants a reboot.
# This step only puts the prerequisites in place so that installer succeeds,
# because on Kali rolling it does not.

# Everything below is meaningless off Parallels. Detect and bail quietly.
_is_parallels() {
  local virt=""
  have systemd-detect-virt && virt=$(systemd-detect-virt 2>/dev/null || true)
  [ "$virt" = "parallels" ] && return 0
  grep -qi parallels /sys/class/dmi/id/product_name 2>/dev/null && return 0
  return 1
}

if ! _is_parallels; then
  skip "not running under Parallels — nothing to prepare"
  return 0
fi

step "Parallels Guest Tools prerequisites"

# --- kernel module build deps ----------------------------------------------
# Tools builds prl_fs/prl_eth/prl_tg via dkms against the running kernel.
# Kali names headers per-release; fall back to the arm64 metapackage when the
# exact release is not in the archive (common right after a kernel bump).
_headers="linux-headers-$(uname -r)"
if ! apt-cache show "$_headers" >/dev/null 2>&1; then
  warn "$_headers not in the archive — falling back to linux-headers-arm64"
  _headers="linux-headers-arm64"
fi
apt_ensure dkms build-essential "$_headers"

# --- libfuse.so.2 -----------------------------------------------------------
# The Tools installer marks libfuse2 mandatory and aborts the whole product
# when apt cannot supply it:
#
#   E: Package 'libfuse2' has no installation candidate
#   Error: failed to install mandatory packages.
#
# fuse 2.x is EOL and gone from Debian testing, which Kali rolling tracks. The
# time64 rename produced libfuse2t64, but that exists only in trixie and sid,
# not forky — so on this box NEITHER name resolves. Patching the installer to
# say libfuse2t64 does not help; the library is absent from the archive.
#
# Only one shipped binary needs it: prl_fsd, the shared-folders daemon.
# prlcp, prldnd, prltoolsd, prltimesync and prl_nettool have no fuse linkage.
# So this gates shared folders alone, but the installer treats it as mandatory
# for everything and they all fail together.
#
# installer/pm.sh's check_libfuse2() tests for the shared object, not for a
# package name:
#
#   ldconfig -p 2>/dev/null | grep -Fq 'libfuse.so.2'
#
# So supplying the library is enough, and it survives Tools updates — unlike
# editing pm.sh, which lives on a read-only ISO that Parallels re-ships on
# every version bump.
FUSE2_DEB="libfuse2t64_2.9.9-9_arm64.deb"
FUSE2_URL="http://ftp.us.debian.org/debian/pool/main/f/fuse/$FUSE2_DEB"
FUSE2_SHA="c92aa3f45505aa5fbc4495e621e76edbfbfdd5ea33e90fd9c977b8b3b8df6543"

_have_libfuse2() { ldconfig -p 2>/dev/null | grep -Fq 'libfuse.so.2'; }

if _have_libfuse2; then
  skip "libfuse.so.2 already present"
elif apt-cache policy libfuse2t64 2>/dev/null | grep -q 'Candidate: [^(]'; then
  # Kali carrying it again is the outcome we want. Prefer the archive.
  ok "libfuse2t64 is back in the archive — using apt"
  apt_ensure libfuse2t64
else
  # Pulled from Debian trixie. Its only dependency is libc6 (>= 2.38), and its
  # Conflicts (fuse << 2.9.9-9, libfuse2 << 2.9.9-9) are moot here since Kali
  # ships neither. Checksum is pinned; a mismatch aborts rather than installs.
  step "fetching libfuse2t64 from Debian trixie (absent from Kali)"
  _tmp=$(mktemp -d)
  if curl -fsSL --retry 3 -o "$_tmp/$FUSE2_DEB" "$FUSE2_URL"; then
    if echo "$FUSE2_SHA  $_tmp/$FUSE2_DEB" | sha256sum -c - >/dev/null 2>&1; then
      sudo dpkg -i "$_tmp/$FUSE2_DEB"
      ok "installed libfuse2t64 2.9.9-9"
    else
      rm -rf "$_tmp"
      die "checksum mismatch on $FUSE2_DEB — refusing to install"
    fi
  else
    warn "could not download $FUSE2_DEB"
    warn "Parallels Tools will fail on 'libfuse2 has no installation candidate'"
    warn "see CLAUDE.md for the fallback that skips shared folders"
  fi
  rm -rf "$_tmp"
fi

# A command exiting 0 is not evidence. Check the thing the installer checks.
if _have_libfuse2; then
  ok "libfuse.so.2 resolves — Tools installer will not stall on it"
else
  warn "libfuse.so.2 still missing — Tools install will abort on libfuse2"
fi

# libfuse2t64 is not in Kali's archive, so it shows as locally installed with
# no candidate and gets no updates. It is an EOL leaf library read only by
# prl_fsd. Do not let a dependency audit or `apt autoremove --purge` remove it.
skip "libfuse2t64 is intentionally a foreign package — see CLAUDE.md"

if [ ! -d "/media/$USER/Parallels Tools" ]; then
  warn "Tools ISO not mounted — Parallels menu: Actions > Install Parallels Tools"
fi
