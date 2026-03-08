# CLAUDE.md

## Project overview

Personal dotfiles repository for macOS and Arch Linux. Manages shell, editor, terminal, and tool configurations.

## Repository structure

- `lib/core/` - Zsh config loaded early (env vars, shell options, key bindings)
- `lib/after/` - Zsh config loaded last (fzf, tool integrations like eza, zoxide, bat, yazi)
- `sheldon/plugins.toml` - Sheldon plugin manager config (manages oh-my-zsh plugins, powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting, fzf-git)
- `zsh/zshrc` - Main zshrc, kept minimal — delegates to sheldon and lib/
- `zsh/rfv` - Ripgrep fuzzy viewer script
- `git/` - Git config and global ignore
- `tmux/` - Tmux config with gruvbox-dark hard theme
- `kitty/` - Kitty terminal config
- `gitui/` - Gitui theme (gruvbox-dark hard) and vim-like key bindings
- `yazi/` - Yazi file manager config
- `aerospace/` - AeroSpace window manager config (macOS only)
- `ideavim/` - IdeaVim config for JetBrains IDEs
- `vim/` - Git submodule, plugins managed by vim-plug
- `nvim/` - Git submodule, plugins managed by lazy.nvim
- `symlinks` - Declarative symlink mappings (all platforms)
- `symlinks.darwin` - macOS-specific symlink mappings
- `setup_symlinks.sh` - Reads symlink map files and creates symlinks

## Key conventions

- **Theme**: Gruvbox dark hard across all tools (tmux, gitui, bat, vim)
- **Plugin management**: Sheldon for zsh, vim-plug for vim, lazy.nvim for neovim
- **Cross-platform**: Configs work on both macOS and Arch Linux
- **`$DOTFILES`**: Resolved dynamically from zshrc symlink via `${${(%):-%x}:A:h:h}`, exported as env var
- **`$SHELDON_CONFIG_DIR`**: Points to `$DOTFILES/sheldon`
- **Symlinks**: Managed via declarative map files (`symlinks`, `symlinks.darwin`, `symlinks.linux`), not hardcoded in scripts
- **Sheldon load order**: `lib/core/` -> completions -> compinit -> ohmyzsh-lib -> ohmyzsh-plugins -> fzf-git -> powerlevel10k -> `lib/after/` -> zsh-autosuggestions -> zsh-syntax-highlighting
- **Submodules**: Only `vim/` and `nvim/` remain as git submodules

## Working with this repo

- When modifying `vim/` or `nvim/`, they are git submodules — commit inside the submodule directory
- This machine may not have git credentials configured for the submodules — use `git format-patch` to generate patches for pushing elsewhere
- Adding a new zsh config: drop a `*.zsh` file into `lib/core/` (early) or `lib/after/` (late)
- Adding a new symlink: append a line to `symlinks` (or `symlinks.darwin`/`symlinks.linux`)
- Sheldon env var expansion: `local` paths in `plugins.toml` don't support `$VAR` — use `inline` plugins with shell code instead
