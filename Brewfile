# Brewfile — macOS package manifest
#
#   brew bundle install --file=Brewfile      # install everything
#   brew bundle check   --file=Brewfile      # what's missing
#   brew bundle dump    --file=Brewfile -f   # regenerate from this machine
#
# Run via ./bootstrap.sh, which handles Homebrew installation first.

tap "hashicorp/tap", trusted: true
tap "nikitabobko/tap", trusted: true

# --- Core CLI referenced by the configs in this repo ---
# Fuzzy finder (lib/after/fzf.zsh, zsh/rfv)
brew "fzf"
# Simple, fast and user-friendly alternative to find
brew "fd"
# Search tool like grep and The Silver Searcher
brew "ripgrep"
# Modern, maintained replacement for ls (lib/after/tools.zsh)
brew "eza"
# Clone of cat(1) with syntax highlighting and Git integration
brew "bat"
# Shell extension to navigate your filesystem faster
brew "zoxide"
# Blazing fast terminal file manager written in Rust, based on async I/O
brew "yazi"
# Syntax-highlighting pager for git and diff output (git/gitconfig pager)
brew "git-delta"
# Blazing fast terminal-ui for git written in rust
brew "gitui"
# Fast, configurable, shell plugin manager — bootstraps all zsh plugins
brew "sheldon"
# Terminal multiplexer
brew "tmux"
# Distributed revision control system
brew "git"
# Ambitious Vim-fork focused on extensibility and agility
brew "neovim"
# Vi 'workalike' with many additional features
brew "vim"
# Play, record, convert, and stream select audio and video codecs (music function)
brew "ffmpeg"
# Download with resuming and segmented downloading
brew "aria2"

# --- General CLI ---
# Simple, modern, secure file encryption
brew "age"
# Official Amazon AWS command-line interface
brew "awscli"
# Yet another cross-platform graphical process/system monitor
brew "bottom"
# Tool for exploring each layer in a docker image
brew "dive"
# Disk Usage/Free Utility - a better 'df' alternative
brew "duf"
# Like neofetch, but much faster because written mostly in C
brew "fastfetch"
# Collection of GNU find, xargs, and locate
brew "findutils"
# GitHub command-line tool
brew "gh"
# Tools and libraries to manipulate images in select formats
brew "imagemagick"
# Command-line pager for JSON data
brew "jless"
# Lightweight and flexible command-line JSON processor
brew "jq"
# Free (GNU) replacement for the Pico text editor
brew "nano"
# NCurses Disk Usage
brew "ncdu"
# Port scanning utility for large networks
brew "nmap"
# 7-Zip (high compression file archiver) implementation
brew "p7zip"
# 7-Zip is a file archiver with a high compression ratio
brew "sevenzip"
# SVG rendering tool and library
brew "resvg"
# Intuitive find & replace CLI
brew "sd"
# Internet file retriever
brew "wget"

# --- Languages / toolchains ---
# Open source programming language to build simple/reliable/efficient software
brew "go"
# Powerful, lightweight programming language
brew "lua"
# Package manager for the Lua programming language
brew "luarocks"
# Parser generator tool (nvim treesitter)
brew "tree-sitter-cli"
# Extremely fast Python package installer and resolver, written in Rust
brew "uv"
# Terraform
brew "hashicorp/tap/terraform"

# --- Casks ---
# AeroSpace is an i3-like tiling window manager for macOS
cask "nikitabobko/tap/aerospace"
# GPU-based terminal emulator
cask "kitty"
# Password manager app
cask "keepassxc"
# Terminal-based AI coding assistant
cask "claude-code@latest"
# Knowledge base that works on top of a local folder of plain text Markdown files
cask "obsidian"
# Multi-platform web browser
cask "microsoft-edge"
# Voice and text chat software
cask "discord"
# Tunneling proxy
cask "shadowsocksx-ng"
# Desktop client for Webull Financial LLC
cask "webull"

# --- Fonts (kitty / tmux / p10k all assume a Nerd Font) ---
cask "font-jetbrains-mono-nerd-font"
cask "font-fantasque-sans-mono-nerd-font"
cask "font-symbols-only-nerd-font"

# --- Go tools (installed to $GOPATH/bin, not Homebrew) ---
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

# --- Not installable here; see MIGRATION.md ---
# Mac App Store (sign in with your Apple ID, then redownload from Purchased):
#   WeChat, Transocks, Pages Creator Studio, and the Apple iWork/iLife apps
# Direct download:
#   TurboTax, 央视频HD
