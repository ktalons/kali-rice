#!/usr/bin/env bash
#
# kali-rice — bootstrap
#
# Idempotent. Run it as many times as you like; a second run should change
# nothing and print mostly dimmed "already ..." lines.
#
#   ./bootstrap.sh              run every step
#   ./bootstrap.sh 20 40        run only the steps whose numeric prefix matches
#   ./bootstrap.sh --list       show available steps
#
set -euo pipefail

RICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RICE_ROOT
# One backup dir per invocation, shared by every step.
export RICE_BACKUP_DIR="$HOME/.rice-backup/$(date +%Y%m%d-%H%M%S)"

# shellcheck source=install/lib.sh
source "$RICE_ROOT/install/lib.sh"

steps=("$RICE_ROOT"/install/[0-9][0-9]-*.sh)

if [ "${1:-}" = "--list" ]; then
  printf 'available steps:\n'
  for s in "${steps[@]}"; do printf '  %s\n' "$(basename "$s")"; done
  exit 0
fi

require_not_root
require_kali

# Fail early and loudly rather than half-way through an apt transaction.
have sudo || die "sudo is required"
sudo -v || die "sudo authentication failed"

selected=()
if [ $# -gt 0 ]; then
  for want in "$@"; do
    for s in "${steps[@]}"; do
      [[ "$(basename "$s")" == "$want"-* ]] && selected+=("$s")
    done
  done
  [ ${#selected[@]} -gt 0 ] || die "no steps matched: $*"
else
  selected=("${steps[@]}")
fi

printf '\n\033[38;5;183m  kali-rice\033[0m  \033[2mCatppuccin Mocha · XFCE · HTB\033[0m\n'
printf '  \033[2mbackups -> %s\033[0m\n\n' "${RICE_BACKUP_DIR/#$HOME/\~}"

for s in "${selected[@]}"; do
  printf '\n\033[38;5;183m── %s ──\033[0m\n' "$(basename "$s" .sh)"
  # shellcheck disable=SC1090
  source "$s"
done

printf '\n\033[38;5;114m  done.\033[0m\n'
if [ -d "$RICE_BACKUP_DIR" ]; then
  printf '  \033[38;5;180mfiles were displaced — see %s\033[0m\n' "${RICE_BACKUP_DIR/#$HOME/\~}"
else
  printf '  \033[2mnothing was displaced.\033[0m\n'
fi

# A skipped XFCE step is the one failure that looks like success from the
# outside — everything else ran, but the desktop is untouched. Say so last,
# where it will actually be read.
if [ "${RICE_XFCE_SKIPPED:-0}" = "1" ]; then
  printf '\n  \033[38;5;174m▲ a session-only step did not run — desktop and/or keybindings are stock.\033[0m\n'
  printf '  \033[38;5;180m  log into XFCE, then: ./bootstrap.sh 50 60\033[0m\n\n'
else
  printf '  \033[2mlog out and pick "Xfce Session" at the greeter.\033[0m\n\n'
fi
