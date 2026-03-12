# Dotfiles

Personal configurations for macOS, Arch Linux, and Windows. Gruvbox dark hard theme and vim-style key bindings everywhere.

## Setup

```sh
git clone --recursive <repo-url> ~/MyConfigurations
cd ~/MyConfigurations
./setup_symlinks.sh          # macOS / Linux
# .\setup_symlinks.ps1       # Windows (PowerShell, run as admin for symlinks)
```

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
powershell/       - PowerShell config: profile, git aliases, dirhistory (Windows)
aria2/            - aria2 download manager (shared config + per-platform setup)
aerospace/        - AeroSpace window manager (macOS)
wt/               - Windows Terminal settings
ideavim/          - IdeaVim config for JetBrains IDEs (requires Which-Key plugin)
vim/              - Vim config (submodule, vim-plug)
nvim/             - Neovim config (submodule, lazy.nvim, cross-platform)
cheatsheet.md     - Key bindings reference (view with `keys`)
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

## Quick Reference

Run `keys` in your terminal to view the key bindings cheatsheet for all tools.
