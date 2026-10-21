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
- `powershell/` - PowerShell config (Windows, loaded via a stub at `$PROFILE` that `install_modules.ps1` writes into `Documents\PowerShell\`, OneDrive-redirected or not): profile.ps1, git.ps1 (oh-my-zsh-style aliases), dirhistory.ps1, music.ps1, install_modules.ps1 (pwsh only — refuses to run under Windows PowerShell 5.1), update.ps1 (attended monthly update, pwsh only — every step's update, then every cleanup, then what's left for you), cleanup.ps1 (the cleanups alone), runner.ps1 (dot-sourced by both: the helpers, `$todo`, `Invoke-Steps`; the counterpart of `unix/runner.zsh`), steps/ (`NN-tool.ps1`, numbered as the same tool is on macOS and Arch, each returning `@{ Update = {…}; Cleanup = {…} }`: 10-windows-update, 20-scoop, 31-rust, 32-uv (the cache junction to D:, `uv cache prune`), 42-nvim (the same headless commands as `unix/steps/42-nvim.zsh`), 43-yazi, 44-ps-modules (cleanup: old versions not loaded in the session), 50-drivers (driver and BIOS report; cleanup deletes the unused driver packages you approve from one elevated window, by starting itself as admin with `-Remove`), 51-aria2 (the same as on macOS and Arch for `~\.config\aria2`, keeping the `dir=` line `install.ps1 -DownloadDir` wrote as well; flags a missing or disabled task), 60-temp (week-old TEMP files), 80-settings (registry and service drift)), update_reminder.ps1 + Update-Reminder.vbs (Patch Tuesday toast from a scheduled task; runs under Windows PowerShell for its WinRT toast API, so keep it ASCII)
- `glazewm/` - GlazeWM tiling window manager config (Windows only, Hyprland-like keybindings)
- `flow-launcher/` - Flow Launcher plugins (Windows only): Music (fzf-less playlist player via mpv). Python dependencies must be manually installed into the plugin's `lib/` folder with `pip install -r requirements.txt -t lib`
- `wt/` - Windows Terminal settings
- `ideavim/` - IdeaVim config for JetBrains IDEs (keybindings aligned with nvim, requires [Which-Key](https://plugins.jetbrains.com/plugin/15976-which-key) plugin)
- `vim/` - Git submodule, plugins managed by vim-plug (has own CLAUDE.md)
- `nvim/` - Git submodule, plugins managed by lazy.nvim, cross-platform macOS/Linux/Windows (has own CLAUDE.md)
- `voice/` - `voice-dictate`, hold-to-talk speech input for Wayland (Arch only): records the
  default PipeWire source, transcribes locally with whisper.cpp on the GPU (ggml-vulkan, no
  CUDA toolkit), and types the text into the focused window via `wtype`. Bound to SUPER+Z in
  the Hyprland config, which lives in the `~/.dotfiles.git` bare repo, not here. The model
  (`ggml-large-v3-turbo-q5_0.bin`, 574 MB) plus a Silero VAD model live in
  `~/.local/share/whisper.cpp/`, downloaded by `bootstrap.arch.sh --voice` rather than tracked.
  VAD is not optional: without it Whisper turns room tone into confident filler text
- `cheatsheet.md` - Key bindings reference for macOS/Linux tools (view with `keys` command)
- `powershell/cheatsheet.md` - Key bindings reference for Windows (PowerShell aliases, git, gitui)
- `symlinks` - Declarative symlink mappings (all platforms)
- `symlinks.darwin` - macOS-specific symlink mappings
- `symlinks.linux` - Linux-specific symlink mappings (the update-reminder systemd user units, `voice-dictate`, makepkg's `~/.config/pacman/makepkg.conf`)
- `symlinks.windows` - Windows-specific symlink mappings
- `Brewfile` - macOS package manifest (formulae, casks, fonts, Go tools). Scoped to what *this repo's* configs need — personal apps and general-purpose CLI live in MIGRATION.md instead, and must not be added back here. `brew bundle dump --file=Brewfile -f` regenerates from the machine and pulls all of that back in, so re-trim after dumping. Never run `brew bundle` with `--cleanup` against it
- `bootstrap.sh` - macOS new-machine setup: Xcode CLT, Homebrew, `brew bundle`, submodules, `setup_symlinks.sh`, machine-local shell stubs, the update reminder's launch agent. Idempotent, never overwrites existing files. Flags: `--no-brew`, `--rust`
- `MIGRATION.md` - New-Mac runbook for everything outside the repo: SSH keys, personal apps, personal data paths, known gotchas, monthly updates
- `unix/` - What the macOS and Arch monthly updates share. runner.zsh: the helpers, the `todo` list, and `run_steps`, which runs one phase (update or cleanup) of every step in `unix/steps/` and the platform's `steps/`, in number order. steps/: 30-go (`go install` for the Brewfile's `go` lines, flags Go tools it doesn't list; cleanup `go clean -modcache`), 31-rust, 32-uv (`uv python upgrade`; cleanup uninstalls the Pythons it replaced unless a venv was made against one directly, then `uv cache prune`), 40-sheldon, 41-vim (`+PlugUpgrade +PlugUpdate`, flags a new plug.vim to commit in the submodule; names the plugins it updated, and the failures from `PlugUpdate`'s window, saved before vim quits and clears the screen), 42-nvim (headless `Lazy! sync`, then `MasonToolsUpdateSync` in a second nvim, parsers left to the nvim config's auto-update; nvim exits 0 regardless, so it reads lazy's red error lines and asks mason what's still behind), 43-yazi
- `mac/` - macOS monthly update, the counterpart of the PowerShell pair: update.sh (attended — every step's update, then every cleanup, then what's left for you), cleanup.sh (the cleanups alone), steps/ (10-softwareupdate: lists Software Update and opens it in System Settings; 20-homebrew: `brew upgrade` reopening apps a cask quit to upgrade, the Brewfile and `brew doctor` checks, cleanup `brew cleanup --prune=all`; 51-aria2: aria2/darwin's install script copies rather than links, since the tracker refresh rewrites `aria2.conf`, so this brings the installed tracker script and launch agents back in line with the repo, rewrites the installed `aria2.conf` from the repo's keeping its `bt-tracker=` line, reloads or restarts what changed, and flags an agent not loaded; 80-settings: what a macOS update can reset — the login-shell PATH, and a table of the `defaults` values MIGRATION.md has you set: natural scrolling off, and the AeroSpace and network-share settings), update-reminder.sh (an `osascript` notification, so it shows as Script Editor, on the same due date as the Windows reminder, the day after Patch Tuesday; `--register` writes and loads its launch agent `local.monthly-update-reminder`, at login and daily at noon, which `bootstrap.sh` does)
- `pkglist.arch` - Arch package manifest. Scoped to what *this repo's* configs need — the desktop (Hyprland, waybar, greetd, fcitx5, theming, GUI apps, drivers) is installed separately and must not be added here. One package per line, `#` comments, `aur/` prefix marks AUR packages
- `bootstrap.arch.sh` - Arch new-machine setup: `pkglist.arch` via pacman (paru only if an `aur/` entry exists), submodules, `setup_symlinks.sh`, machine-local shell stubs, `chsh` to zsh, yazi plugins, enables `update-reminder.timer`. Idempotent, never overwrites existing files. Flags: `--no-pkg`, `--rust`, `--aria2`, `--voice`, `--print-packages`
- `MIGRATION.arch.md` - New-Arch-box runbook: SSH keys, the `~/.dotfiles.git` bare repo (no remote — must be copied), personal data paths, known gotchas, monthly updates
- `arch/` - Arch monthly update, the counterpart of the PowerShell pair: update.sh (attended, zsh like the rest of `unix/` — every step's update, then every cleanup, then what's left for you), cleanup.sh (the cleanups alone), steps/ (20-pacman: reflector, `paru -Syu`, restarts aria2 and flags tmux when an upgrade replaced the binary they run, pacdiff; 50-ge-proton; 51-aria2: the same as macOS's for aria2/linux's systemd user units, flagging a unit not enabled; 80-settings: systemd-boot still first in the boot order, which Windows Update can take; 81-health: failed units, orphans, deleted AUR packages; 85-reboot: kernel or NVIDIA driver replaced), update-reminder.sh + update-reminder.{service,timer} (systemd user timer, linked in by `symlinks.linux`; a notify-send notification on the same due date as the Windows reminder, the day after Patch Tuesday, with an Update now button that opens kitty), kooldots-upgrade.sh (attended upgrade of KooL's `~/Arch-Hyprland` installer and its Hyprland-Dots, which own `~/.config/hypr` — a tarball and a `~/.dotfiles.git` tag first, then `update-deps.sh` and `copy.sh --express-upgrade` with `$ZSH` pointed at sheldon's Oh My Zsh; then puts back what express mode overwrites: qt5ct/qt6ct from the bare repo, the yazi symlinks, the waybar power-profiles-daemon removal (waybar 0.15 segfaults in it on an early reload) and the tray-style removal, the kitty include; re-adds this machine's Hyprland user settings if missing, and checks the user Lua files, which Hyprland would skip silently if broken, and `Hyprland --verify-config`. `--post-only` runs just the repairs and checks, idempotent; they follow `$XDG_CONFIG_HOME`, so they can be tried on a copy), makepkg.conf (makepkg's user overrides for AUR builds: no `-debug` packages, fast compression; linked in by `symlinks.linux`)
- `MIGRATION.windows.md` - Windows 11 LTSC (re)install runbook for the dual-boot box: backing up C: to `D:\Migration`, shared ESP on the Windows disk holds Arch's kernel, restoring systemd-boot afterwards, Windows settings (key remap, locale, dark mode, telemetry), scoop packages, profile stub, SSH keys, network share, personal apps and data, monthly updates
- `setup_symlinks.sh` - Reads symlink map files and creates symlinks, skips existing files/symlinks (macOS/Linux)
- `setup_symlinks.ps1` - Windows equivalent of setup_symlinks.sh. Saved as UTF-8 **with BOM** — without it Windows PowerShell 5.1 misreads the emoji and fails to parse; keep the BOM when editing

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
- Adding a monthly update or cleanup step (macOS, Arch): drop `NN-tool.zsh` into `unix/steps/` (both) or `mac/steps/`/`arch/steps/`, defining `update()`, `cleanup()` or both; `unix/runner.zsh` has the contract and the numbering. On Windows: `NN-tool.ps1` in `powershell/steps/`, with the same number, returning its `Update`/`Cleanup` script blocks; `powershell/runner.ps1` has the contract
- Adding a new symlink: append a line to `symlinks` (or `symlinks.darwin`/`symlinks.linux`/`symlinks.windows`)
- Sheldon env var expansion: `local` paths in `plugins.toml` don't support `$VAR` — use `inline` plugins with shell code instead
- `rm` is aliased to `rm -i` (from oh-my-zsh common-aliases) — use `command rm` in shell commands to bypass the interactive prompt
