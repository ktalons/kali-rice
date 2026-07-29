# shellcheck shell=bash
# Shared state helpers for htb-box / htb-target / htb-vpn.
#
# State is deliberately one value per file rather than a single parsed file.
# The prompt and three polybar modules read these on every refresh, and a
# bare `cat` of a 12-byte file is the cheapest thing that can work.

HTB_ROOT="${HTB_ROOT:-$HOME/htb}"
HTB_STATE="${HTB_STATE:-$HOME/.htb}"
HTB_HOSTS_MARK="# kali-rice htb"

mkdir -p "$HTB_STATE"

C_RESET=$'\033[0m'; C_MAUVE=$'\033[38;5;183m'; C_RED=$'\033[38;5;174m'
C_GREEN=$'\033[38;5;114m'; C_DIM=$'\033[2m'; C_YELLOW=$'\033[38;5;180m'

hsay()  { printf '%s::%s %s\n' "$C_MAUVE" "$C_RESET" "$*"; }
hok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
hwarn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
hdie()  { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

state_get() { [ -r "$HTB_STATE/$1" ] && cat "$HTB_STATE/$1" || true; }
state_set() { printf '%s' "$2" > "$HTB_STATE/$1"; }
state_clear() { rm -f "$HTB_STATE/$1"; }

# The VPN interface is never cached — it is read from the kernel every time.
# A cached "connected" that outlived the tunnel is exactly the kind of
# silent-success lie this whole setup is built to avoid.
vpn_iface() {
  ip -o -4 addr show 2>/dev/null | awk '$2 ~ /^tun[0-9]+$/ {print $2; exit}'
}

vpn_ip() {
  ip -o -4 addr show 2>/dev/null \
    | awk '$2 ~ /^tun[0-9]+$/ {split($4, a, "/"); print a[1]; exit}'
}

valid_target() {
  # An IPv4 address or a hostname. Rejects shell metacharacters outright,
  # because this value reaches /etc/hosts and a tmux window title.
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}
