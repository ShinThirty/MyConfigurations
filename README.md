# Dotfiles

Personal configurations for macOS, Arch Linux, and Windows. Gruvbox dark hard theme and vim-style key bindings everywhere.

## Setup

```sh
git clone --recursive <repo-url> ~/MyConfigurations
cd ~/MyConfigurations
./setup_symlinks.sh
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

### Neovim

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Open neovim and plugins will be installed automatically.

## Structure

```
lib/
  core/           - Shell config loaded early (env vars, options)
  after/          - Shell config loaded last (fzf, eza, zoxide, bat, yazi)
sheldon/          - Sheldon plugin manager config
zsh/              - Zshrc and utilities
git/              - Git config and global ignore
tmux/             - Tmux config
kitty/            - Kitty terminal config
gitui/            - Gitui theme and key bindings
yazi/             - Yazi file manager config
aerospace/        - AeroSpace window manager (macOS)
ideavim/          - IdeaVim config for JetBrains IDEs
vim/              - Vim config (submodule, vim-plug)
nvim/             - Neovim config (submodule, lazy.nvim, cross-platform)
cheatsheet.md     - Key bindings reference (view with `keys`)
symlinks          - Symlink mappings (all platforms)
symlinks.darwin   - macOS-specific symlink mappings
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
