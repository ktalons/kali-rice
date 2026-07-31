# shellcheck shell=bash
# Shared helpers for the kali-rice install steps.
# Everything here exists to make re-running bootstrap.sh a no-op.

set -euo pipefail

RICE_ROOT="${RICE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RICE_BACKUP_DIR="${RICE_BACKUP_DIR:-$HOME/.rice-backup/$(date +%Y%m%d-%H%M%S)}"
RICE_MARKER="# >>> kali-rice >>>"
RICE_MARKER_END="# <<< kali-rice <<<"

C_RESET=$'\033[0m'; C_BLUE=$'\033[38;5;111m'; C_GREEN=$'\033[38;5;114m'
C_YELLOW=$'\033[38;5;180m'; C_RED=$'\033[38;5;174m'; C_DIM=$'\033[2m'

step() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip() { printf '  %s·%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$*" "$C_RESET"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Refuse to run as root. Everything installs into $HOME; sudo is escalated
# per-command instead. Running the whole script as root leaves root-owned
# files in the user's home, which then break silently on the next run.
require_not_root() {
  [ "$(id -u)" -ne 0 ] || die "Do not run as root. Run as your normal user; sudo is used per-command."
}

require_kali() {
  grep -qi kali /etc/os-release || die "This targets Kali. /etc/os-release says otherwise."
}

# --- apt -------------------------------------------------------------------

pkg_installed() {
  local status
  status=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)
  [[ "$status" == *"ok installed"* ]]
}

# Install only what is genuinely missing, so a rerun makes zero apt calls.
apt_ensure() {
  local missing=()
  for p in "$@"; do
    pkg_installed "$p" || missing+=("$p")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    skip "all ${#@} packages already installed"
    return 0
  fi
  step "installing ${#missing[@]} package(s): ${missing[*]}"
  sudo apt-get install -y "${missing[@]}"
}

apt_refresh_once() {
  local stamp=/var/lib/apt/periodic/kali-rice-update
  if [ -f "$stamp" ] && [ "$(find "$stamp" -mmin -180 2>/dev/null)" ]; then
    skip "apt lists refreshed within the last 3h"
    return 0
  fi
  step "apt-get update"
  sudo apt-get update
  sudo mkdir -p "$(dirname "$stamp")" && sudo touch "$stamp"
}

# --- files -----------------------------------------------------------------

backup_path() {
  local target="$1"
  [ -e "$target" ] || [ -L "$target" ] || return 0
  mkdir -p "$RICE_BACKUP_DIR"
  local rel="${target#"$HOME"/}"
  local dest="$RICE_BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
  warn "backed up $rel -> ${RICE_BACKUP_DIR#"$HOME"/}/$rel"
}

# Symlink src -> dst, backing up anything real that is in the way.
# Already-correct symlinks are left completely alone, so reruns add no
# entries to the backup dir. That property is what verification checks.
link_file() {
  local src="$1" dst="$2"
  [ -e "$src" ] || die "missing source: $src"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skip "${dst#"$HOME"/} already linked"
    return 0
  fi
  backup_path "$dst"
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "linked ${dst#"$HOME"/}"
}

# Append a fenced block to a file exactly once, keyed by marker.
# Re-running replaces the block rather than stacking duplicates.
ensure_block() {
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qF "$RICE_MARKER" "$file"; then
    # Rewrite in place between the markers so edits to the block propagate.
    local tmp; tmp=$(mktemp)
    awk -v s="$RICE_MARKER" -v e="$RICE_MARKER_END" '
      $0 == s {skipping=1; next}
      $0 == e {skipping=0; next}
      !skipping {print}
    ' "$file" > "$tmp"
    printf '%s\n%s\n%s\n' "$RICE_MARKER" "$content" "$RICE_MARKER_END" >> "$tmp"
    mv "$tmp" "$file"
    skip "refreshed kali-rice block in ${file#"$HOME"/}"
  else
    printf '\n%s\n%s\n%s\n' "$RICE_MARKER" "$content" "$RICE_MARKER_END" >> "$file"
    ok "added kali-rice block to ${file#"$HOME"/}"
  fi
}

# Clone if absent, otherwise leave the working copy untouched. Never pulls —
# a rerun that silently updates a plugin is a rerun that can break a working
# setup without saying so.
git_ensure() {
  local url="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    skip "${dest#"$HOME"/} already cloned"
    return 0
  fi
  backup_path "$dest"
  step "cloning $(basename "$dest")"
  git clone --depth 1 "$url" "$dest"
}

have() { command -v "$1" >/dev/null 2>&1; }

# --- xfconf ----------------------------------------------------------------

# Set an xfconf property and read it back. Anything that does not stick is
# fatal, not a warning — a desktop that half-applied is worse than one that
# did not.
#
# Named xfset, not xset: `xset` is also the X11 binary, and a shell function
# by that name silently shadows it for every step sourced afterwards.
xfset() {
  local channel="$1" prop="$2" type="$3" value="$4"
  local current
  current=$(xfconf-query -c "$channel" -p "$prop" 2>/dev/null || true)
  if [ "$current" = "$value" ]; then
    skip "$channel$prop already = $value"
    return 0
  fi
  xfconf-query -c "$channel" -p "$prop" --create -t "$type" -s "$value" >/dev/null 2>&1 \
    || die "failed to set $channel$prop"
  current=$(xfconf-query -c "$channel" -p "$prop" 2>/dev/null || true)
  [ "$current" = "$value" ] \
    || die "$channel$prop did not stick (wanted '$value', got '$current')"
  ok "$channel$prop = $value"
}

# Refuse to touch xfconf from outside a live session. xfconf-query talks to
# xfconfd over the session bus; from a TTY, another WM, or prlctl there is
# nothing to talk to and every setting is silently discarded. Callers `return`
# on a non-zero result — the step is skipped, the run continues, and the
# final summary says so.
xfconf_session_ready() {
  if xfconf-query -c xsettings -l >/dev/null 2>&1; then
    ok "xfconfd is reachable"
    return 0
  fi
  RICE_XFCE_SKIPPED=1
  printf '\n'
  warn "SKIPPING this step — no session on the bus. Nothing here was applied."
  warn ""
  warn "Log into XFCE (pick 'Xfce Session' at the greeter), open a terminal"
  warn "there, and run:   ./bootstrap.sh 50 60"
  printf '\n'
  return 1
}
