# CLAUDE.md

## Project overview

Personal dotfiles repository for macOS, Arch Linux, and Windows. Manages shell, editor, terminal, and tool configurations.

## Repository structure

- `lib/core/` - Zsh config loaded early (env vars, shell options, key bindings)
- `lib/after/` - Zsh config loaded last (fzf, tool integrations like eza, zoxide, bat, yazi, music)
- `sheldon/plugins.toml` - Sheldon plugin manager config (manages oh-my-zsh plugins, powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting, fzf-git)
- `zsh/zshrc` - Main zshrc, kept minimal — delegates to sheldon and lib/
- `zsh/rfv` - Ripgrep fuzzy viewer script
- `git/` - Git config (platform-specific gitconfig files) and global ignore
- `tmux/` - Tmux config with gruvbox-dark hard theme
- `kitty/` - Kitty terminal config with vim-like key bindings
- `gitui/` - Gitui theme (gruvbox-dark hard) and vim-like key bindings
- `yazi/` - Yazi file manager config with gruvbox theme
- `aerospace/` - AeroSpace tiling window manager config (macOS only)
- `aria2/` - aria2 download manager config, per-platform install scripts (darwin/, linux/, windows/)
- `powershell/` - PowerShell config (Windows, loaded via stub from OneDrive `$PROFILE`): profile.ps1, git.ps1 (oh-my-zsh-style aliases), dirhistory.ps1, music.ps1, install_modules.ps1
- `glazewm/` - GlazeWM tiling window manager config (Windows only, Hyprland-like keybindings)
- `flow-launcher/` - Flow Launcher plugins (Windows only): Music (fzf-less playlist player via mpv). Python dependencies must be manually installed into the plugin's `lib/` folder with `pip install -r requirements.txt -t lib`
- `wt/` - Windows Terminal settings
- `ideavim/` - IdeaVim config for JetBrains IDEs (keybindings aligned with nvim, requires [Which-Key](https://plugins.jetbrains.com/plugin/15976-which-key) plugin)
- `vim/` - Git submodule, plugins managed by vim-plug (has own CLAUDE.md)
- `nvim/` - Git submodule, plugins managed by lazy.nvim, cross-platform macOS/Linux/Windows (has own CLAUDE.md)
- `cheatsheet.md` - Key bindings reference for macOS/Linux tools (view with `keys` command)
- `powershell/cheatsheet.md` - Key bindings reference for Windows (PowerShell aliases, git, gitui)
- `symlinks` - Declarative symlink mappings (all platforms)
- `symlinks.darwin` - macOS-specific symlink mappings
- `symlinks.windows` - Windows-specific symlink mappings
- `setup_symlinks.sh` - Reads symlink map files and creates symlinks, skips existing files/symlinks (macOS/Linux)
- `setup_symlinks.ps1` - Windows equivalent of setup_symlinks.sh

## Key conventions

- **Theme**: Gruvbox dark hard across all tools (tmux, gitui, bat, vim, kitty, yazi)
- **Key bindings**: Vim-style navigation (h/j/k/l) across all tools where possible
- **Plugin management**: Sheldon for zsh, vim-plug for vim, lazy.nvim for neovim
- **Cross-platform**: macOS (AeroSpace, Homebrew), Arch Linux (Hyprland, pacman), and Windows (GlazeWM, PowerShell, git, gitui, nvim, Windows Terminal, aria2)
- **`$DOTFILES`**: Resolved dynamically from zshrc symlink via `${${(%):-%x}:A:h:h}`, exported as env var
- **`$SHELDON_CONFIG_DIR`**: Points to `$DOTFILES/sheldon`
- **Symlinks**: Managed via declarative map files (`symlinks`, `symlinks.darwin`, `symlinks.linux`, `symlinks.windows`), not hardcoded in scripts
- **Sheldon load order**: `lib/core/` -> completions -> compinit -> ohmyzsh-lib -> ohmyzsh-plugins -> fzf-git -> powerlevel10k -> `lib/after/` -> zsh-autosuggestions -> zsh-syntax-highlighting
- **Submodules**: Only `vim/` and `nvim/` remain as git submodules

## Bare repo dotfiles

Configs not managed by this symlink-based repo (Hyprland, waybar, wofi, etc.) are managed via a git bare repo at `~/.dotfiles.git`. Setup:

```sh
git init --bare ~/.dotfiles.git
cfg config status.showUntrackedFiles no
```

The `cfg` alias (defined in `lib/after/tools.zsh`) works like `git` but targets `~/.dotfiles.git`:

```sh
cfg add ~/.config/hypr/ ~/.config/waybar/
cfg commit -m "initial commit"
cfg push
```

## Working with this repo

- When modifying `vim/` or `nvim/`, they are git submodules — commit inside the submodule directory, then generate patches with `git format-patch`
- Do not specify `-c user.name` or `-c user.email` when committing in submodules — the machine's git config already has the correct credentials
- Use `git format-patch` to generate patches for pushing from another machine with `git am`
- Adding a new zsh config: drop a `*.zsh` file into `lib/core/` (early) or `lib/after/` (late)
- Adding a new symlink: append a line to `symlinks` (or `symlinks.darwin`/`symlinks.linux`/`symlinks.windows`)
- Sheldon env var expansion: `local` paths in `plugins.toml` don't support `$VAR` — use `inline` plugins with shell code instead
- `rm` is aliased to `rm -i` (from oh-my-zsh common-aliases) — use `command rm` in shell commands to bypass the interactive prompt
