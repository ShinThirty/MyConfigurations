#!/usr/bin/env bash
#
# bootstrap.sh — bring a fresh macOS machine up to this dotfiles setup.
#
#   ./bootstrap.sh              # full run
#   ./bootstrap.sh --no-brew    # skip Homebrew + Brewfile
#   ./bootstrap.sh --rust       # also install rustup
#
# Idempotent: safe to re-run. Never overwrites an existing file.
# Secrets (SSH keys) are NOT handled here — see MIGRATION.md.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_BREW=1
INSTALL_RUST=0
for arg in "$@"; do
  case "$arg" in
    --no-brew) INSTALL_BREW=0 ;;
    --rust)    INSTALL_RUST=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*"; }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m⚠️\033[0m  %s\n' "$*"; }

[[ "$OSTYPE" == darwin* ]] || { echo "bootstrap.sh is macOS-only (got $OSTYPE)" >&2; exit 1; }

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

# `brew shellenv` MUST run from ~/.zprofile, and nowhere earlier.
#
# /etc/zprofile runs `path_helper`, which rebuilds PATH with the system dirs
# first and demotes everything else to the end. `brew shellenv` re-runs
# path_helper with PATH_HELPER_ROOT=$(brew --prefix), promoting the Homebrew
# dirs back to the front. Since ~/.zprofile is sourced *after* /etc/zprofile,
# Homebrew wins — but only from there. Put the same line in ~/.zshenv (sourced
# before /etc/zprofile) or add /opt/homebrew/bin to /etc/paths, and path_helper
# demotes it: `git` then resolves to /usr/bin/git instead of Homebrew's.
#
# This appends to an existing ~/.zprofile rather than skipping it, because a
# fresh Mac often already has one that lacks the line.
ensure_brew_shellenv() {
  local zprofile="$HOME/.zprofile" prefix line
  prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
  line="eval \"\$($prefix/bin/brew shellenv)\""

  if [[ ! -e "$zprofile" ]]; then
    printf '%s\n' "$line" > "$zprofile"
    ok "~/.zprofile created (brew shellenv)"
  elif grep -q 'brew shellenv' "$zprofile"; then
    skip "~/.zprofile already runs brew shellenv"
  else
    printf '\n%s\n' "$line" >> "$zprofile"
    ok "~/.zprofile appended (brew shellenv)"
  fi

  if grep -rqs 'brew shellenv' "$HOME/.zshenv"; then
    warn "~/.zshenv also runs brew shellenv — remove it"
    warn "it is sourced before /etc/zprofile, so path_helper demotes Homebrew"
  fi
  if grep -qs "$prefix/bin" /etc/paths /etc/paths.d/* 2>/dev/null; then
    warn "$prefix/bin is listed in /etc/paths(.d) — remove it"
    warn "path_helper will order it after /usr/bin and shadow Homebrew tools"
  fi
}

# --- Xcode Command Line Tools -------------------------------------------------
info "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  skip "already installed"
else
  xcode-select --install || true
  echo
  echo "  A GUI installer was launched. Re-run ./bootstrap.sh when it finishes."
  exit 1
fi

# --- Homebrew -----------------------------------------------------------------
if (( INSTALL_BREW )); then
  info "Homebrew"
  if ! command -v brew >/dev/null 2>&1; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
  fi
  ok "$(brew --version | head -1) at $(brew --prefix)"

  info "Brewfile"
  brew bundle install --file="$DOTFILES/Brewfile"
  ok "packages installed"
else
  info "Homebrew"
  skip "skipped (--no-brew)"
fi

# --- Submodules ---------------------------------------------------------------
info "Submodules (vim, nvim)"
git -C "$DOTFILES" submodule update --init --recursive
ok "vim/ and nvim/ checked out"

# --- Symlinks -----------------------------------------------------------------
info "Symlinks"
"$DOTFILES/setup_symlinks.sh"

# --- Shell stubs (machine-local, deliberately not tracked in the repo) --------
info "Machine-local shell files"

ensure_brew_shellenv

write_if_missing "$HOME/.zshenv" <<'EOF'
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
EOF

write_if_missing "$HOME/.zshrc.local" <<'EOF'
# Machine-local zsh config, sourced at the end of zsh/zshrc.
# Keep secrets and per-machine paths here — this file is not in the repo.

# Go
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Haskell (only if ghcup is installed)
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
EOF

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

# --- PATH sanity check --------------------------------------------------------
# Verify in a real login shell, since that is where /etc/zprofile's path_helper
# runs and where the ordering can go wrong.
if (( INSTALL_BREW )); then
  info "PATH check (login shell)"
  brew_prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
  resolved_git="$(zsh -lic 'command -v git' 2>/dev/null | tr -d '\r')"
  if [[ "$resolved_git" == "$brew_prefix"/* ]]; then
    ok "git resolves to $resolved_git"
  elif [[ -z "$resolved_git" ]]; then
    warn "could not resolve git in a login shell"
  else
    warn "git resolves to $resolved_git, not $brew_prefix/bin/git"
    warn "open a new login shell and check: echo \$PATH | tr : '\\n' | head"
    warn "$brew_prefix/bin must appear before /usr/bin — see MIGRATION.md"
  fi
fi

# --- Next steps ---------------------------------------------------------------
info "Done — remaining manual steps"
cat <<'EOF'
  1. SSH keys — copy from the old Mac (see MIGRATION.md "SSH keys"):
       ~/.ssh/github  ~/.ssh/sourcehut  ~/.ssh/signing_key{,.pub}
       ~/.ssh/config  ~/.ssh/allowed_signers
     then:  chmod 700 ~/.ssh && chmod 600 ~/.ssh/* && chmod 644 ~/.ssh/*.pub
  2. exec zsh          # sheldon fetches all plugins on first run
  3. Open nvim         # lazy.nvim installs plugins automatically
  4. vim +PlugInstall +qa
  5. Grant AeroSpace + kitty Accessibility permission in System Settings
  6. Set the kitty font to a Nerd Font if it did not pick one up
  7. gh auth login     # if you use the GitHub CLI
EOF
