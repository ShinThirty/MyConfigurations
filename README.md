# Dotfiles

Personal configurations for macOS, Arch Linux, and Windows. Gruvbox dark hard theme and vim-style key bindings everywhere.

## Setup

```sh
git clone --recursive <repo-url> ~/MyConfigurations
cd ~/MyConfigurations
./bootstrap.sh               # macOS: Homebrew + Brewfile + symlinks + shell stubs
# ./bootstrap.arch.sh        # Arch Linux: pacman + pkglist.arch + symlinks + shell stubs
# .\setup_symlinks.ps1       # Windows (PowerShell, run as admin for symlinks)
# ./setup_symlinks.sh        # any Unix, symlinks only
```

On a brand-new machine, follow the matching runbook — it covers what the
bootstrap script can't: SSH keys, apps, and personal data outside this repo.

- macOS → [MIGRATION.md](MIGRATION.md)
- Arch Linux → [MIGRATION.arch.md](MIGRATION.arch.md)

`pkglist.arch` covers only what this repo's configs need. The desktop
(Hyprland, waybar, greetd, fcitx5, GUI apps) is installed separately and its
configs live in the `~/.dotfiles.git` bare repo below.

### Zsh

Plugins are managed by [sheldon](https://github.com/rossmacarthur/sheldon).

```sh
# macOS
brew install sheldon

# Arch Linux
pacman -S sheldon
```

Restart your shell and sheldon will fetch all plugins on first run.

### Vim

Plugins are managed by [vim-plug](https://github.com/junegunn/vim-plug). Open vim and run `:PlugInstall`.

### PowerShell (Windows)

```powershell
.\powershell\install_modules.ps1
```

This creates a stub profile at the OneDrive `$PROFILE` path that dot-sources `powershell/profile.ps1` from this repo, and installs PSGallery modules (CompletionPredictor, posh-git, Terminal-Icons, PSFzf).

The profile includes oh-my-posh (gruvbox theme), oh-my-zsh-style git aliases, fzf/fd integration, zoxide, bat, yazi, dirhistory (Alt+Arrow navigation), and CompletionPredictor for argument-aware predictions.

### Bare repo dotfiles

Configs not managed by this repo (Hyprland, waybar, wofi, etc.) can be tracked via a git bare repo:

```sh
git init --bare ~/.dotfiles.git
cfg config status.showUntrackedFiles no
cfg add ~/.config/hypr/ ~/.config/waybar/
cfg commit -m "initial commit"
```

The `cfg` alias is defined in `lib/after/tools.zsh` and activates when `~/.dotfiles.git` exists.

### Neovim

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Open neovim and plugins will be installed automatically.

## Structure

```
lib/
  core/           - Shell config loaded early (env vars, options)
  after/          - Shell config loaded last (fzf, eza, zoxide, bat, yazi)
sheldon/          - Sheldon plugin manager config
zsh/              - Zshrc and utilities
git/              - Git config (per-platform gitconfig files) and global ignore
tmux/             - Tmux config
kitty/            - Kitty terminal config
gitui/            - Gitui theme and key bindings
yazi/             - Yazi file manager config
powershell/       - PowerShell config: profile, git aliases, dirhistory, music (Windows)
aria2/            - aria2 download manager (shared config + per-platform setup)
aerospace/        - AeroSpace window manager (macOS)
glazewm/          - GlazeWM tiling window manager (Windows, Hyprland-like)
flow-launcher/    - Flow Launcher plugins (Windows): Music playlist player (mpv + yt-dlp)
wt/               - Windows Terminal settings
ideavim/          - IdeaVim config for JetBrains IDEs (requires Which-Key plugin)
vim/              - Vim config (submodule, vim-plug)
nvim/             - Neovim config (submodule, lazy.nvim, cross-platform)
cheatsheet.md     - Key bindings reference (view with `keys`)
MIGRATION.md      - New-Mac runbook: SSH keys, apps, personal data
MIGRATION.arch.md - New-Arch-box runbook: SSH keys, bare repo, personal data
Brewfile          - macOS package manifest (only what this repo's configs need)
pkglist.arch      - Arch package manifest (same scope, pacman)
bootstrap.sh      - New-Mac setup: Homebrew, Brewfile, submodules, symlinks, stubs
bootstrap.arch.sh - New-Arch setup: pacman, pkglist.arch, submodules, symlinks, stubs
setup_symlinks.sh - Creates symlinks, skips existing files/symlinks (macOS/Linux)
setup_symlinks.ps1- Windows equivalent
symlinks          - Symlink mappings (all platforms)
symlinks.darwin   - macOS-specific symlink mappings
symlinks.windows  - Windows-specific symlink mappings
```

## Dependencies

Core CLI tools used across configs:

- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder
- [fd](https://github.com/sharkdp/fd) - File finder
- [ripgrep](https://github.com/BurntSushi/ripgrep) - Fast grep
- [eza](https://github.com/eza-community/eza) - Modern ls
- [bat](https://github.com/sharkdp/bat) - Cat with syntax highlighting
- [zoxide](https://github.com/ajeetdsouza/zoxide) - Smarter cd
- [yazi](https://github.com/sxyazi/yazi) - Terminal file manager
- [delta](https://github.com/dandavison/delta) - Git diff viewer
- [mpv](https://mpv.io/) - Media player (music function)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Media downloader (music function)

## Quick Reference

Run `keys` in your terminal to view the key bindings cheatsheet for all tools.
