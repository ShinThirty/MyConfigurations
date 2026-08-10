#!/usr/bin/env bash
#
# bootstrap.arch.sh — bring a fresh Arch Linux machine up to this dotfiles setup.
#
#   ./bootstrap.arch.sh                    # full run
#   ./bootstrap.arch.sh --no-pkg           # skip pkglist.arch
#   ./bootstrap.arch.sh --rust             # also install rustup
#   ./bootstrap.arch.sh --aria2            # also install the aria2 systemd user units
#   ./bootstrap.arch.sh --print-packages   # print the parsed package list, then exit
#
# Scope matches pkglist.arch: the tools this repo's configs need, nothing else.
# Arch itself (kernel, drivers, bootloader) is the installer's job, and the
# desktop — Hyprland, waybar, greetd, fcitx5, GUI apps — is set up separately;
# its configs live in the ~/.dotfiles.git bare repo.
#
# Idempotent: safe to re-run. Never overwrites an existing file.
# Secrets (SSH keys) are NOT handled here — see MIGRATION.arch.md.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGLIST="$DOTFILES/pkglist.arch"

INSTALL_PKG=1
INSTALL_RUST=0
INSTALL_ARIA2=0
PRINT_PACKAGES=0
for arg in "$@"; do
  case "$arg" in
    --no-pkg)          INSTALL_PKG=0 ;;
    --rust)            INSTALL_RUST=1 ;;
    --aria2)           INSTALL_ARIA2=1 ;;
    --print-packages)  PRINT_PACKAGES=1 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*"; }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m⚠️\033[0m  %s\n' "$*"; }

# Strip comments and blank lines. `aur/` prefixes are left intact: they are
# valid paru targets and they document where a package comes from.
parse_pkglist() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$PKGLIST"
}

if (( PRINT_PACKAGES )); then
  parse_pkglist | tr '\n' ' '
  echo
  exit 0
fi

command -v pacman >/dev/null 2>&1 ||
  { echo "bootstrap.arch.sh needs pacman — this is the Arch script" >&2; exit 1; }
[[ $EUID -ne 0 ]] ||
  { echo "run this as your normal user, not root (it calls sudo where needed)" >&2; exit 1; }

# Write a file only if it does not already exist.
write_if_missing() {
  local path="$1"
  if [[ -e "$path" ]]; then
    skip "${path/#$HOME/~} (exists)"
  else
    cat > "$path"
    ok "${path/#$HOME/~}"
  fi
}

# paru is itself an AUR package, so it has to be built by hand once.
ensure_paru() {
  if command -v paru >/dev/null 2>&1; then
    skip "paru already installed"
    return
  fi
  local tmp
  sudo pacman -S --needed --noconfirm base-devel git
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  ok "paru built and installed"
}

# --- Packages -----------------------------------------------------------------
if (( INSTALL_PKG )); then
  info "Packages (pkglist.arch)"
  mapfile -t packages < <(parse_pkglist)
  if printf '%s\n' "${packages[@]}" | grep -q '^aur/'; then
    ensure_paru
    paru -S --needed "${packages[@]}"
  else
    # No AUR entries, so pacman is enough — no helper required on a fresh box.
    sudo pacman -S --needed "${packages[@]}"
  fi
  ok "${#packages[@]} packages installed"
else
  info "Packages"
  skip "skipped (--no-pkg)"
fi

# --- Submodules ---------------------------------------------------------------
info "Submodules (vim, nvim)"
git -C "$DOTFILES" submodule update --init --recursive
ok "vim/ and nvim/ checked out"

# --- Symlinks -----------------------------------------------------------------
info "Symlinks"
"$DOTFILES/setup_symlinks.sh"

# --- Shell stubs (machine-local, deliberately not tracked in the repo) --------
# No PATH gymnastics needed here: /usr/bin is the only bin dir that matters on
# Arch, so unlike macOS there is no ~/.zprofile ordering problem to work around.
info "Machine-local shell files"

write_if_missing "$HOME/.zshenv" <<'EOF'
# Machine-local environment, read by every zsh (login or not).

# Input method — harmless if fcitx5 is not installed
export XMODIFIERS=@im=fcitx

# pinentry program for GPG prompts
export PINENTRY=/usr/bin/pinentry-qt

if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
EOF

write_if_missing "$HOME/.zshrc.local" <<'EOF'
# Machine-local zsh config, sourced at the end of zsh/zshrc.
# Keep secrets and per-machine paths here — this file is not in the repo.

# Go
export PATH="$PATH:$(go env GOPATH)/bin"

# Haskell (only if ghcup is installed)
if [ -f "$HOME/.ghcup/env" ]; then . "$HOME/.ghcup/env"; fi
EOF

# --- Login shell --------------------------------------------------------------
info "Login shell"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" == */zsh ]]; then
  skip "already $current_shell"
elif [[ -x /usr/bin/zsh ]]; then
  if chsh -s /usr/bin/zsh; then
    ok "login shell set to /usr/bin/zsh (takes effect on next login)"
  else
    warn "chsh failed — run it yourself: chsh -s /usr/bin/zsh"
  fi
else
  warn "zsh is not installed — install it, then: chsh -s /usr/bin/zsh"
fi

# --- Rust (optional) ----------------------------------------------------------
if (( INSTALL_RUST )); then
  info "Rust"
  if command -v rustup >/dev/null 2>&1; then
    skip "rustup already installed"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    ok "rustup installed (stable toolchain)"
  fi
fi

# --- aria2 (optional) ---------------------------------------------------------
if (( INSTALL_ARIA2 )); then
  info "aria2"
  # install.sh resolves ../aria2.conf relative to its own directory and writes
  # into $XDG_CONFIG_HOME, which is not exported outside an interactive zsh.
  (cd "$DOTFILES/aria2/linux" && XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" bash install.sh)
  ok "config and systemd user units installed — enable them as printed above"
fi

# --- Yazi plugins -------------------------------------------------------------
# `ya` resolves its config dir via the OS user config path, not $HOME, so this
# always acts on the real ~/.config/yazi regardless of how the script is invoked.
info "Yazi plugins"
if ! command -v ya >/dev/null 2>&1; then
  skip "yazi not installed yet — run 'ya pkg install' after installing it"
elif ya pkg install; then
  ok "plugins synced from yazi/package.toml"
else
  warn "ya pkg install failed"
  warn "if it reports locally modified plugins, re-run with: ya pkg install --discard"
fi

# --- Next steps ---------------------------------------------------------------
info "Done — remaining manual steps"
cat <<'EOF'
  1. SSH keys — copy from the old machine (see MIGRATION.arch.md "SSH keys"):
       ~/.ssh/github  ~/.ssh/sourcehut  ~/.ssh/signing_key{,.pub}
       ~/.ssh/config  ~/.ssh/allowed_signers
     then:  chmod 700 ~/.ssh && chmod 600 ~/.ssh/* && chmod 644 ~/.ssh/*.pub
  2. exec zsh          # sheldon fetches all plugins on first run
  3. Open nvim         # lazy.nvim installs plugins automatically
  4. vim +PlugInstall +qa
  5. gh auth login     # if you use the GitHub CLI (pacman -S github-cli)
  6. The desktop (Hyprland, waybar, fcitx5, GUI apps) is set up separately —
     its configs live in the ~/.dotfiles.git bare repo. See MIGRATION.arch.md.
EOF
