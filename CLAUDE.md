# CLAUDE.md

Personal dotfiles for macOS, Arch Linux and Windows: shell, editor, terminal and tool configs, and
each platform's setup, monthly update and settings checks.

This file is the layout and the conventions. What a script does, and what a check covers, is in the
script's header comment; the steps done by hand are in the runbooks. So a new script, step or check
doesn't change this file: a new top-level entry, convention or workflow does.

## Layout

Configs, linked in by the symlink maps:

- `zsh/` - zshrc, kept minimal (it delegates to sheldon and `lib/`), and `rfv`
- `lib/core/`, `lib/after/` - zsh config loaded first and last
- `sheldon/` - the zsh plugin config
- `git/`, `tmux/`, `kitty/`, `gitui/`, `yazi/`, `ideavim/` - one tool each
- `vim/`, `nvim/` - the only git submodules, each with its own CLAUDE.md
- `aerospace/` (macOS), `glazewm/` and `wt/` (Windows) - window managers and terminal
- `aria2/` - the config, and an install script for each platform
- `helium/` - the browser's policies and preferences, and the scripts that apply them
- `keepassxc/` - the settings every machine shares, and the scripts that apply them and start it at login
- `voice/` - `voice-dictate`, hold-to-talk dictation (Arch)
- `iphone/` - read-only checks of the iPhone, run from the Mac

Each platform:

- `bootstrap.sh`, `bootstrap.arch.sh` - new-machine setup for macOS and Arch; idempotent, never
  overwrite existing files. Windows is set up by hand from MIGRATION.windows.md
- `Brewfile`, `pkglist.arch` - package manifests
- `symlinks`, `symlinks.{darwin,linux,windows}` - the link maps, read by `setup_symlinks.sh` and
  `setup_symlinks.ps1`
- `unix/` - what the macOS and Arch monthly updates share: `runner.zsh` and `steps/`
- `mac/`, `arch/` - each one's monthly update (`update.sh`, `cleanup.sh`, `steps/`) and that
  platform's own scripts and units
- `powershell/` - Windows: the profile, and the monthly update (`update.ps1`, `cleanup.ps1`,
  `runner.ps1`, `steps/`) with its reminder

Runbooks, for what the repo can't do:

- `MIGRATION.md`, `MIGRATION.arch.md`, `MIGRATION.windows.md` - setting up a Mac, the Arch box and
  Windows: SSH keys, personal apps and data, gotchas, monthly updates
- `SECURITY.md` - security by control, with each platform's steps; the MIGRATION runbooks point here
  rather than repeat it
- `IPHONE.md` - the iPhone: steps in Settings, and a monthly check run from the Mac
- `cheatsheet.md`, `powershell/cheatsheet.md` - key bindings (`keys` shows the first)

## Conventions

- **Public repo**: no secrets, private keys, network names, router addresses, IPs, locations or
  personal lists. Those live in files outside the repo, such as `~/.config/vpn-reminder/trusted`,
  that the scripts read
- **Package manifests**: `Brewfile` and `pkglist.arch` list only what this repo's configs need.
  Personal apps go in the MIGRATION runbooks; the Arch desktop is installed separately. Never run
  `brew bundle` with `--cleanup`, and re-trim after `brew bundle dump`
- **Counterparts**: a script usually has one on the other platforms (`.sh` and `.ps1`,
  `runner.zsh` and `runner.ps1`, steps with the same number); keep them in step
- **Drift**: a setting the repo applies, or one made by hand that a command can read, is checked by
  the platform's `80-settings` step, through the applying script's `--check` (`-Check`) where it has
  one. Security settings are listed under Security, with their SECURITY.md section
- **Monthly update steps**: `NN-tool.zsh` in `unix/steps/` (both) or `mac/steps/`/`arch/steps/`,
  defining `update()`, `cleanup()` or both; on Windows `NN-tool.ps1` in `powershell/steps/`, with
  the same number. `unix/runner.zsh` and `powershell/runner.ps1` have the contract and the numbering
- **Theme and keys**: Gruvbox dark hard, and vim-style (h/j/k/l) bindings, in every tool that allows
- **Plugins**: sheldon for zsh, vim-plug for vim, lazy.nvim for neovim
- **`$DOTFILES`**: resolved from the zshrc symlink via `${${(%):-%x}:A:h:h}`; `$SHELDON_CONFIG_DIR`
  is `$DOTFILES/sheldon`
- **Sheldon load order**: `lib/core/` -> completions -> compinit -> ohmyzsh-lib -> ohmyzsh-plugins
  -> fzf-git -> powerlevel10k -> `lib/after/` -> zsh-autosuggestions -> zsh-syntax-highlighting
- **Encoding**: `setup_symlinks.ps1` keeps its UTF-8 BOM and `powershell/update_reminder.ps1` stays
  ASCII, since Windows PowerShell 5.1 reads them

## Bare repo dotfiles

Configs this repo doesn't link (Hyprland, waybar, wofi, etc.) are in a git bare repo at
`~/.dotfiles.git`, with no remote. The `cfg` alias (`lib/after/tools.zsh`) is `git` for that repo:

```sh
git init --bare ~/.dotfiles.git
cfg config status.showUntrackedFiles no
cfg add ~/.config/hypr/ ~/.config/waybar/
cfg commit -m "initial commit"
```

On Arch, KooL's Hyprland-Dots own `~/.config/hypr` and their upgrade overwrites it;
`arch/kooldots-upgrade.sh` puts back what this machine changed.

## Working with this repo

- `vim/` and `nvim/` are submodules: commit inside the submodule, then `git format-patch` for the
  other machines' `git am`. Don't pass `-c user.name` or `-c user.email`; the machine's git config
  has them
- A new zsh config: a `*.zsh` file in `lib/core/` (early) or `lib/after/` (late)
- A new symlink: a line in `symlinks` or the platform's map
- Sheldon's `local` paths in `plugins.toml` don't expand `$VAR`; use an `inline` plugin instead
- `rm`, `cp` and `mv` are aliased to `-i` (oh-my-zsh common-aliases); use `command rm` and so on
