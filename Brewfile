# Brewfile — macOS package manifest
#
#   brew bundle install --file=Brewfile      # install everything
#   brew bundle check   --file=Brewfile      # what's missing
#   brew bundle dump    --file=Brewfile -f   # regenerate from this machine
#
# Run via ./bootstrap.sh, which handles Homebrew installation first.
#
# Scope: only what the configs in *this* repo need — the macOS counterpart of
# pkglist.arch. Personal apps, general-purpose CLI and anything installed for a
# specific project are deliberately absent; see MIGRATION.md for the list of
# what to reinstall by hand.
#
# Because of that, never run `brew bundle` with `--cleanup` against this file:
# it would uninstall everything not listed here.
#
# `brew bundle dump -f` regenerates from the machine and will pull all of that
# back in — re-trim after dumping, or the scope note above stops being true.

tap "nikitabobko/tap", trusted: true

# --- Core CLI referenced by the configs in this repo ---
# Fuzzy finder (lib/after/fzf.zsh, zsh/rfv)
brew "fzf"
# Simple, fast and user-friendly alternative to find (fzf + yazi backends)
brew "fd"
# Search tool like grep and The Silver Searcher (zsh/rfv)
brew "ripgrep"
# Modern, maintained replacement for ls (lib/after/tools.zsh)
brew "eza"
# Clone of cat(1) with syntax highlighting — also renders `keys`
brew "bat"
# Shell extension to navigate your filesystem faster (lib/after/tools.zsh)
brew "zoxide"
# Blazing fast terminal file manager (yazi/, plus the `y` wrapper)
brew "yazi"
# Syntax-highlighting pager for git and diff output (git/gitconfig pager)
brew "git-delta"
# Blazing fast terminal-ui for git (gitui/, plus the `cfgui` alias)
brew "gitui"
# Fast, configurable, shell plugin manager — bootstraps all zsh plugins
brew "sheldon"
# Terminal multiplexer (tmux/)
brew "tmux"
# Distributed revision control system (git/)
brew "git"
# Ambitious Vim-fork focused on extensibility and agility (nvim/ submodule)
brew "neovim"
# Vi 'workalike' with many additional features (vim/ submodule, $EDITOR)
brew "vim"
# Download with resuming and segmented downloading (aria2/)
brew "aria2"
# GNU find/xargs/locate — the `locate` and `loaddb` aliases in tools.zsh call
# glocate and gupdatedb
brew "findutils"

# --- music function (lib/after/music.zsh) ---
brew "mpv"
brew "yt-dlp"
# Play, record, convert, and stream select audio and video codecs
brew "ffmpeg"

# --- keepassxc/sync.sh ---
# Provides keepassxc-cli, which sync.sh uses to merge the local and SMB copies
cask "keepassxc"

# --- yazi preview helpers ---
# Optional yazi dependencies — previews silently degrade without them.
brew "poppler"
brew "imagemagick"
brew "resvg"
brew "sevenzip"

# --- Editor toolchain ---
# mason.nvim downloads LSP servers and formatters at runtime, and treesitter
# compiles parsers locally. The compiler, curl, unzip and python3 come from the
# Xcode Command Line Tools, which bootstrap.sh installs first; zsh is the macOS
# system shell, so neither needs a formula here.
brew "go"
# Node runtime for the npm-based LSP servers mason installs
brew "node"
brew "lua"
brew "luarocks"
# Parser generator tool (nvim treesitter)
brew "tree-sitter-cli"
# Extremely fast Python package installer and resolver, written in Rust
brew "uv"

# --- Casks ---
# AeroSpace is an i3-like tiling window manager for macOS (aerospace/)
cask "nikitabobko/tap/aerospace"
# GPU-based terminal emulator (kitty/)
cask "kitty"

# --- Fonts (kitty / tmux / p10k all assume a Nerd Font) ---
cask "font-fantasque-sans-mono-nerd-font"
cask "font-jetbrains-mono-nerd-font"
cask "font-symbols-only-nerd-font"

# --- Go tools (installed to $GOPATH/bin, not Homebrew) ---
# nvim's go.nvim setup shells out to these.
go "golang.org/x/tools/gopls"
go "golang.org/x/tools/cmd/goimports"
go "golang.org/x/tools/cmd/callgraph"
go "golang.org/x/tools/cmd/gonew"
go "golang.org/x/vuln/cmd/govulncheck"
go "github.com/go-delve/delve/cmd/dlv"
go "github.com/golangci/golangci-lint/v2/cmd/golangci-lint"
go "mvdan.cc/gofumpt"
go "github.com/segmentio/golines"
go "github.com/fatih/gomodifytags"
go "github.com/abenz1267/gomvp"
go "github.com/davidrjenni/reftools/cmd/fillswitch"
go "github.com/koron/iferr"
go "github.com/josharian/impl"
go "github.com/abice/go-enum"
go "github.com/twpayne/go-jsonstruct/v3/cmd/gojsonstruct"
go "github.com/tmc/json-to-struct"
go "github.com/cweill/gotests/gotests"
go "gotest.tools/gotestsum"
go "github.com/kyoh86/richgo"
go "github.com/onsi/ginkgo/v2/ginkgo"
go "go.uber.org/mock/mockgen"

# --- Everything else lives in MIGRATION.md ---
# Personal apps, general-purpose CLI, App Store and direct-download software
# are listed there under "Apps and tools not covered by the Brewfile".
