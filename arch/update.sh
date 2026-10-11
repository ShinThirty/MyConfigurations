#!/usr/bin/env bash
#
# Monthly update, attended (MIGRATION.arch.md section 10). Run as your normal user.
# Covers what day-to-day `paru` runs don't: mirrors, merging .pacnew files, the
# toolchains and plugins outside pacman, and checks for what needs a reboot or a
# look. Ends with what's left for you. Finishing records the run, which silences
# update-reminder.sh until the next due date.

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/monthly-update"

[[ $EUID -ne 0 ]] ||
  { echo "run this as your normal user, not root (it calls sudo where needed)" >&2; exit 1; }
# Started from the reminder, this runs outside zsh, so nothing from ~/.zshenv is set
# shellcheck source=/dev/null
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*"; }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m⚠️\033[0m  %s\n' "$*"; }
todo=()

# --- Mirrors ------------------------------------------------------------------
info "Mirrors"
# The arguments this machine's mirrorlist was generated with. reflector.conf,
# which reflector.service reads, has different ones and isn't used.
if sudo reflector --protocol https --country 'United States' --latest 20 --sort rate \
     --save /etc/pacman.d/mirrorlist; then
  ok "mirrorlist refreshed"
else
  warn "reflector failed, so the old mirrorlist stays"
fi

# --- Packages -----------------------------------------------------------------
# paru.conf has NewsOnUpgrade (Arch news before the upgrade), Devel (-git
# packages) and SudoLoop
info "System and AUR packages"
paru -Syu || todo+=("paru -Syu didn't finish; run it again")

info "Config files from upgrades (.pacnew, .pacsave)"
mapfile -t pacfiles < <(pacdiff --output)
if (( ${#pacfiles[@]} )); then
  # --sudo goes through sudoedit, so nvim runs as you with your config. v opens
  # the pair (edit the original, :wqa), then r removes the .pacnew; o takes the
  # .pacnew whole; s skips.
  DIFFPROG='nvim -d' pacdiff --sudo
  mapfile -t pacfiles < <(pacdiff --output)
  (( ${#pacfiles[@]} )) &&
    todo+=("Still unmerged, for DIFFPROG='nvim -d' pacdiff --sudo: ${pacfiles[*]}")
else
  skip "none"
fi

# --- Toolchains ---------------------------------------------------------------
info "Rust toolchain"
if command -v rustup >/dev/null 2>&1; then
  rustup update || todo+=("rustup update failed")
else
  skip "rustup not installed"
fi

info "Go tools (the go lines in Brewfile)"
if command -v go >/dev/null 2>&1; then
  mapfile -t gotools < <(sed -n 's/^go "\(.*\)"$/\1/p' "$DOTFILES/Brewfile")
  failed=()
  for tool in "${gotools[@]}"; do
    printf '  %s\n' "${tool##*/}"
    go install "$tool@latest" || failed+=("$tool")
  done
  (( ${#failed[@]} )) && todo+=("go install failed for: ${failed[*]}")
  # Matched by module path rather than name, since go install never removes
  # anything: these are left from earlier lists, and nothing updates them
  gobin="$(go env GOBIN)"
  [[ -n $gobin ]] || gobin="$(go env GOPATH)/bin"
  extra=()
  for bin in "$gobin"/*; do
    path="$(go version -m "$bin" 2>/dev/null | awk '$1 == "path" { print $2; exit }')"
    [[ " ${gotools[*]} " == *" $path "* ]] || extra+=("${bin##*/}")
  done
  (( ${#extra[@]} )) &&
    todo+=("Go tools not in the Brewfile, so never updated — delete them from ${gobin/#"$HOME"/\~} or add them: ${extra[*]}")
else
  skip "go not installed"
fi

info "uv-managed Pythons"
# Venvs point at the minor-version directory, so they pick up the new patch release
uv python upgrade || todo+=("uv python upgrade failed")

# --- Plugins ------------------------------------------------------------------
info "zsh plugins (sheldon)"
# Resets zshrc's own every-14-days prompt to update them
if SHELDON_CONFIG_DIR="$DOTFILES/sheldon" sheldon lock --update; then
  date +%s > "${XDG_CACHE_HOME:-$HOME/.cache}/sheldon_last_update"
else
  todo+=("sheldon lock --update failed")
fi

info "vim plugins"
# vim-plug updates synchronously while vim is starting, so +qa waits for it
vim +PlugUpdate +qa

info "yazi packages"
# ya writes to ~/.config/yazi/package.toml, which reaches the repo only through its symlink
if [[ -L $HOME/.config/yazi/package.toml ]]; then
  # A bump pulled from another machine changes package.toml's hashes under the
  # plugins deployed here, so ya takes them for local edits and aborts
  ya pkg upgrade || todo+=("ya pkg upgrade failed: if it says you modified a plugin you never touched, package.toml was bumped elsewhere: ya pkg install --discard, then ya pkg upgrade")
  [[ -z $(git -C "$DOTFILES" status --porcelain -- yazi/package.toml) ]] ||
    todo+=("Commit the new yazi/package.toml revisions")
else
  warn "yazi's package.toml is a copy, not the repo's symlink"
  todo+=("yazi: swap ~/.config/yazi/package.toml for the repo's symlink (MIGRATION.arch.md section 7), then ya pkg upgrade")
fi

todo+=("nvim: :Lazy update, then :MasonToolsUpdate and :TSUpdate!")

info "GE-Proton"
# ProtonUp-Qt installs it, and only when asked
compat="$HOME/.local/share/Steam/compatibilitytools.d"
installed="$(find "$compat" -maxdepth 1 -name 'GE-Proton*' -printf '%f\n' 2>/dev/null | sort -V | tail -n 1)"
if [[ -z $installed ]]; then
  skip "none installed"
else
  latest="$(curl -fsS -o /dev/null -w '%{redirect_url}' \
    https://github.com/GloriousEggroll/proton-ge-custom/releases/latest)"
  latest="${latest##*/}"
  if [[ -z $latest ]]; then
    warn "couldn't look up the latest release"
  elif [[ -d $compat/$latest ]]; then
    ok "$latest, the latest"
  else
    warn "$latest is out; the newest here is $installed"
    todo+=("GE-Proton: add $latest in ProtonUp-Qt, then move games that pin $installed onto it")
  fi
fi

# --- Health -------------------------------------------------------------------
info "Health"
health=()
mapfile -t units < <({ systemctl --failed --plain --no-legend; systemctl --user --failed --plain --no-legend; } |
  awk '{ print $1 }')
(( ${#units[@]} )) && health+=("Failed units, see systemctl status: ${units[*]}")

mapfile -t orphans < <(pacman -Qdtq)
(( ${#orphans[@]} )) &&
  health+=("Orphans, which nothing depends on: ${orphans[*]} — sudo pacman -Rns \$(pacman -Qdtq)")

# An AUR package that's been deleted stops getting updates without a word from paru
mapfile -t foreign < <(pacman -Qmq)
if (( ${#foreign[@]} )); then
  mapfile -t found < <(paru -Sia "${foreign[@]}" 2>/dev/null | awk '/^Name/ { print $3 }')
  if (( ${#found[@]} )); then
    mapfile -t gone < <(comm -23 <(printf '%s\n' "${foreign[@]}" | sort) <(printf '%s\n' "${found[@]}" | sort))
    (( ${#gone[@]} )) && health+=("Gone from the AUR, so never updated again: ${gone[*]}")
  else
    warn "couldn't reach the AUR to check for deleted packages"
  fi
fi

if (( ${#health[@]} )); then
  warn "${#health[@]} found, listed below"
  todo+=("${health[@]}")
else
  ok "no failed units, orphans or deleted AUR packages"
fi

# --- Reboot -------------------------------------------------------------------
# Upgrading the kernel package deletes the running kernel's modules, and the
# NVIDIA userspace stops talking to the loaded module until both match again
reboot_for=()
[[ -d /usr/lib/modules/$(uname -r) ]] || reboot_for+=("the running kernel $(uname -r) was replaced")
if [[ -r /sys/module/nvidia/version ]]; then
  loaded="$(< /sys/module/nvidia/version)"
  nvidia="$(pacman -Q nvidia-utils 2>/dev/null | awk '{ sub(/-[^-]*$/, "", $2); print $2 }')"
  [[ -z $nvidia || $nvidia == "$loaded" ]] ||
    reboot_for+=("the NVIDIA driver went from $loaded to $nvidia")
fi

# --- Left for you -------------------------------------------------------------
info "Left for you"
for item in "${todo[@]}"; do
  printf '  \033[33m-\033[0m %s\n' "$item"
done
if (( ${#reboot_for[@]} )); then
  printf '  \033[33m-\033[0m Reboot: %s\n' "${reboot_for[@]}"
fi

mkdir -p "$STATE_DIR"
date +%F > "$STATE_DIR/last-run"
printf "\n\033[32mRecorded this month's run; the reminder stays quiet until the next due date\033[0m\n"
