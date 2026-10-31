# Dotfiles

Personal configurations for macOS, Arch Linux and Windows, with Gruvbox dark hard and vim-style key
bindings everywhere.

## Setup

Each platform has a runbook that starts from a clean machine and covers what the repo can't, such as
SSH keys, apps and personal data:

- macOS: [MIGRATION.md](MIGRATION.md), which runs `bootstrap.sh`
- Arch Linux: [MIGRATION.arch.md](MIGRATION.arch.md), which runs `bootstrap.arch.sh`
- Windows 11: [MIGRATION.windows.md](MIGRATION.windows.md)

[SECURITY.md](SECURITY.md) covers security on every machine, and [IPHONE.md](IPHONE.md) the iPhone.

## Monthly updates

`mac/update.sh`, `arch/update.sh` or `powershell/update.ps1` updates everything, cleans up, and then
lists what's left to do by hand. A reminder on each platform says when it's due.

## Notes

- `Brewfile` and `pkglist.arch` list only what these configs need.
- Configs this repo doesn't link, such as Hyprland and waybar, are in a `~/.dotfiles.git` bare repo,
  and `cfg` is `git` for it.
- `keys` shows the key bindings cheatsheet.
