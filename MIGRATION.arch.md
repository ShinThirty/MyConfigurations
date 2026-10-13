# Migrating to a new Arch Linux machine

Runbook for standing this setup up on a fresh Arch install. The automated part
is `bootstrap.arch.sh` + `pkglist.arch`; everything else is listed here because
it can't be (or shouldn't be) checked into a public repo.

Rough order: **install Arch → repo → bootstrap → SSH keys → desktop → personal data → verify.**
After that, [section 10](#10-monthly-updates) keeps it current.

> Scope note: this repo covers the shell, editors, terminal and CLI tooling.
> The **desktop** — Hyprland, waybar, rofi, swaync, greetd, fcitx5, theming,
> GUI apps, drivers — is installed and configured separately; its configs live
> in the `~/.dotfiles.git` bare repo (see [section 5](#5-the-hyprland-bare-repo)).
> `pkglist.arch` deliberately does not duplicate any of it.

---

## 1. Install Arch

Out of scope for this repo, but the decisions that matter downstream:

| Choice | What this setup assumes |
|---|---|
| Kernel | `linux-zen` on the current machine; any kernel works, just keep its `-headers` installed if you use DKMS drivers |
| Microcode | `amd-ucode` or `intel-ucode`, matched to the CPU |
| GPU | `nvidia-open-dkms` (Turing or newer) on the current machine — rebuilds on every kernel bump, so headers must stay in sync |
| Filesystem | Nothing in this repo cares, but `timeshift` snapshots assume Btrfs or an ext4 + rsync setup |
| User | A normal user in `wheel` with sudo. `bootstrap.arch.sh` refuses to run as root |

Get networking up and `sudo pacman -Syu` clean before going further.

---

## 2. Clone and bootstrap

```sh
sudo pacman -S --needed git
git clone --recursive git@github.com:ShinThirty/MyConfigurations.git ~/MyConfigurations
cd ~/MyConfigurations
./bootstrap.arch.sh
```

> The clone uses SSH, so either do [SSH keys](#3-ssh-keys) first, or clone over
> HTTPS and switch the remote afterwards:
> `git remote set-url origin git@github.com:ShinThirty/MyConfigurations.git`

`bootstrap.arch.sh` is idempotent and never overwrites an existing file. It:

1. Installs everything in `pkglist.arch` (`pacman -S --needed`; it only builds
   paru if the list has grown an `aur/` entry)
2. Checks out the `vim/` and `nvim/` submodules
3. Runs `setup_symlinks.sh` (`symlinks`, then `symlinks.linux`)
4. Enables the monthly update reminder ([section 10](#10-monthly-updates))
5. Creates `~/.zshenv` and `~/.zshrc.local` if missing
6. Sets the login shell to `/usr/bin/zsh` via `chsh`
7. Runs `ya pkg install` for yazi plugins

Flags: `--no-pkg` to skip package installation, `--rust` to also install rustup,
`--aria2` to install aria2's config and systemd user units, `--voice` to
download the models for voice dictation, `--print-packages` to just dump the
parsed list. aria2 and voice dictation each leave a step for you, below.

Unlike the macOS script there is no `~/.zprofile` / PATH ordering step —
`/usr/bin` is the only bin dir that matters here, so nothing shadows anything.

**aria2** (`--aria2`). Copies `aria2.conf` and the tracker script into
`~/.config/aria2/`, and the systemd user units into `~/.config/systemd/user/`;
enabling them is left to you. It creates an empty `aria2.session` only if none
exists, so to resume unfinished downloads, copy the old machine's
`~/.config/aria2/aria2.session` there first — once aria2 runs, it rewrites the
file every minute. Then:

```sh
systemctl --user enable --now aria2.service
systemctl --user enable --now aria2_update_tracker.timer   # weekly tracker refresh
systemctl --user start aria2_update_tracker.service        # trackers now: the repo's aria2.conf has none
```

By hand, `aria2/linux/install.sh` only works from inside `aria2/linux/` (it
copies `../aria2.conf`), and from zsh: it writes to `$XDG_CONFIG_HOME/aria2`,
which only an interactive zsh exports, so from bash it would write to `/aria2`.
The flag takes care of both. Downloads go to `~/Downloads`; for incoming
BitTorrent peers, forward 6881–6999 on the router. `arch/update.sh` restarts
aria2 when an upgrade replaces its binary. The installed files are copies,
since the tracker refresh rewrites `aria2.conf`, and the same update brings
them back in line with the repo, keeping only the tracker line, so a local edit
to them doesn't last.

**Voice dictation** (`--voice`). Downloads the two models `voice-dictate` needs
into `~/.local/share/whisper.cpp/`: Whisper large-v3-turbo (574 MB), and the
Silero VAD model, without which silence comes out as confident filler text.
`pkglist.arch` installs whisper.cpp with its Vulkan backend and `wtype`, the
desktop brings `pw-record` and `notify-send`, `symlinks.linux` links the script
into `~/.local/bin`, and the SUPER+Z binding is in the Hyprland config, from the
bare repo ([section 5](#5-the-hyprland-bare-repo)). Then:

```sh
voice-dictate doctor   # dependencies, models, mic and GPU backend
```

**IdeaVim.** `symlinks` links `~/.ideavimrc`, which matters once a JetBrains
IDE is installed. Install the **IdeaVim** and **Which-Key** plugins from the
IDE's Marketplace: the config's `set which-key` needs the second for its
key-binding popup. The other plugins it loads (surround, commentary, NERDTree,
…) are built into IdeaVim.

---

## 3. SSH keys

The only secrets this migration covers. Copy these six files from the old
machine (USB or `scp` — **not** email or chat):

| File | What it's for |
|---|---|
| `~/.ssh/github` | GitHub auth (RSA 4096, no passphrase comment) |
| `~/.ssh/sourcehut` | git.sr.ht auth (ed25519) |
| `~/.ssh/signing_key` | Git commit signing (ed25519) |
| `~/.ssh/signing_key.pub` | Referenced by `user.signingkey` in `git/gitconfig` |
| `~/.ssh/config` | Host→key mapping for github.com and git.sr.ht |
| `~/.ssh/allowed_signers` | Referenced by `gpg.ssh.allowedSignersFile` |

Fix permissions after copying — SSH refuses to use world-readable keys:

```sh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/github ~/.ssh/sourcehut ~/.ssh/signing_key ~/.ssh/allowed_signers ~/.ssh/config
chmod 644 ~/.ssh/signing_key.pub
```

Verify:

```sh
ssh -T git@github.com                  # "Hi ShinThirty! You've successfully authenticated"
ssh -T git@git.sr.ht
git -C ~/MyConfigurations log --show-signature -1   # should say "Good git signature"
```

`~/.ssh/known_hosts` is not worth copying — it regenerates on first connect.

**Alternative to copying:** generate a fresh keypair and add it to
GitHub/sourcehut. If you do that for `signing_key`, you must also append the new
public key to `~/.ssh/allowed_signers` (and keep the old line, or past commits
stop verifying).

---

## 4. Git config

`symlinks` points `~/.gitconfig` at `git/gitconfig`, which is shared with macOS.
Nothing in it is macOS-specific.

Commit signing is SSH-based (`user.signingkey = ~/.ssh/signing_key.pub`,
`gpg.ssh.allowedSignersFile = ~/.ssh/allowed_signers`), so it works as soon as
section 3 is done — no GPG agent or keychain helper involved.

---

## 5. The Hyprland bare repo

The desktop config is **not** in this repo. It lives in a git bare repo at
`~/.dotfiles.git`, which tracks `~/.config/hypr` and the qt5ct and qt6ct
settings.

**It has no remote.** Nothing is pushed anywhere, so it has to be copied off the
old machine wholesale or it's gone:

```sh
# on the old machine
rsync -a ~/.dotfiles.git/ newbox:~/.dotfiles.git/

# on the new machine
git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME config status.showUntrackedFiles no
git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME checkout
```

The `cfg` alias (from `lib/after/tools.zsh`) activates as soon as
`~/.dotfiles.git` exists, so after a restarted shell it's just `cfg status`.

If `checkout` refuses because a file already exists, back the conflicting file
up and re-run — the repo's copy is the one you want.

Worth doing while you're here: give it a private remote so the next migration is
a `clone` instead of an `rsync`.

The desktop **packages** are a separate concern from the configs. Install the
session and its tools the way you normally do (Hyprland, waybar, rofi, swaync,
wlogout, cliphist, grim/slurp/swappy, greetd, fcitx5, the Qt/GTK theming stack,
GUI apps) — `pkglist.arch` intentionally leaves all of it out. `pacman -Qqe` on
the old machine is the honest checklist.

**Upgrading KooL's Hyprland setup.** `~/.config/hypr` started as KooL's
Hyprland-Dots, installed by the `~/Arch-Hyprland` installer. Upgrade them with
`arch/kooldots-upgrade.sh`, not KooL's `copy.sh --express-upgrade` alone: that
replaces qt5ct, qt6ct and yazi, which this repo and the bare repo own, undoes
two waybar fixes, and installs a second Oh My Zsh beside sheldon's. The script
backs up first (a tarball and a bare-repo tag), runs the upgrade, puts all of
that back, re-adds this machine's Hyprland settings if they're missing (the
SUPER+Z dictation binding among them), and checks that the config loads.
`--post-only` runs just the repairs and checks. It's safe to rerun, and worth a
run after a fresh KooL install too, since the installer replaces the same
files; what it can't fix, it lists at the end.

---

## 6. Personal data to bring over

None of this is in the repo. Decide case by case what you actually still need.

> This repo is public, so the table below is deliberately generic. Work through
> it against the actual dotfiles in `$HOME` on the old machine — `ls -A ~` and
> `ls ~/.config` are the real checklist.

| What | Notes |
|---|---|
| Password manager database | `~/.local/share/keepass/*.kdbx`. A second copy lives on the network share; `keepassxc/sync.sh` merges both ways, but it hardcodes the macOS `/Volumes/...` mount path — fix that before running it here. Its `backups/` dir is disposable. |
| Encryption identity | The age key under `~/.config/age`. Anything encrypted to it is **unrecoverable** without this file — copy it or lose access. |
| Broker / API credential file | Plaintext keys. Copy directly, never into this repo. Rotating them as part of the move is the safer play. |
| Trading working dir | Local SQLite DB plus scratch subdirectories. |
| `~/.aws/config` | Profile definitions only, no secrets. Copy it, then re-authenticate; the `login/cache` and `cli/cache` dirs are disposable. |
| `~/.claude/settings.json` | Claude Code prefs. `projects/`, `sessions/`, `history.jsonl` are per-machine history — copy only if you want it. |
| `~/Music/playlists/` | Plain-text playlists the `music` function reads. Small, easy to forget. |
| `~/.local/share/nvim/sessions`, shada | Optional editor state. |
| `~/.zsh_history` | Optional, along with the fzf history dir. |
| `~/.config/hypr` | Comes from the bare repo above, not from a manual copy. |

**Regenerate rather than copy:** `~/.rustup`, `~/.cargo`, `~/.npm`, `~/.cache`,
`~/.local/share/sheldon`, `~/.local/share/nvim`, `~/.local/share/yazi`,
`~/go/pkg`, `~/.ghcup`. These are caches and toolchains that rebuild themselves.

---

## 7. Known gotchas

**`chsh` doesn't apply to the current session.** `bootstrap.arch.sh` sets the
login shell, but you stay in bash until the next login. `exec zsh` to try it
immediately; log out and back in to make it stick for the display manager too.

**Go tools are not in `pkglist.arch`.** The macOS `Brewfile` lists ~22
`go "..."` entries (gopls, dlv, golangci-lint, gofumpt, …) that nvim's Go setup
expects. `arch/update.sh` installs and updates that list
([section 10](#10-monthly-updates)), so its first run doubles as the install. By
hand it's the same everywhere:

```sh
go install golang.org/x/tools/gopls@latest      # and the rest of the Brewfile list
```

They land in `$(go env GOPATH)/bin`, which the generated `~/.zshrc.local` puts
on PATH.

**`~/.config/yazi/package.toml` drift.** `setup_symlinks.sh` skips paths that
already exist, so if a real file is there from an older setup the symlink is
never created and `ya pkg install` uses stale plugin pins. On the current Linux
box `yazi.toml` and `theme.toml` are symlinks but `package.toml` is not — delete
it and re-run `setup_symlinks.sh`, then `ya pkg install`.

**DKMS drivers and kernel upgrades.** `nvidia-open-dkms` needs the matching
`linux-zen-headers` present *before* the kernel package upgrades, or you reboot
into a machine with no GPU driver. Keep both in the same `pacman -Syu`.

**GitHub key is RSA.** `~/.ssh/github` is a 4096-bit RSA key with no comment.
Still accepted by GitHub, but a good moment to rotate to ed25519.

---

## 8. Verification

```sh
exec zsh                                  # sheldon fetches plugins on first run
which fzf fd rg eza bat zoxide yazi delta gitui sheldon
ls -la ~/.zshrc ~/.gitconfig ~/.config/nvim ~/.config/kitty   # all symlinks into the repo
echo $DOTFILES                            # /home/<you>/MyConfigurations

# anything from pkglist.arch that didn't make it
for p in $(./bootstrap.arch.sh --print-packages); do
  pacman -Qq "${p#aur/}" >/dev/null 2>&1 || echo "missing: $p"
done
```

Then:

- `nvim` — lazy.nvim installs plugins on first launch; `:checkhealth` after
- `vim +PlugInstall +qa`
- `tmux` — prefix keys and gruvbox theme active
- `gitui` in a repo — gruvbox theme, vim keys
- `y` — yazi opens, previews render, and the shell follows its cwd on quit
- `keys` — opens the cheatsheet
- `music` — playlist picker comes up (needs `~/Music/playlists/`)
- `git commit` on a scratch change, then `git log --show-signature`
- `cfg status` — the Hyprland bare repo is wired up

---

## 9. Decommissioning the old machine

1. Confirm the `~/.dotfiles.git` bare repo made it across — it has no remote
2. Push or copy any unpushed work in local git repos
3. Remove the old SSH keys from GitHub and sourcehut **if** you rotated instead of copying
4. Rotate the broker/API keys if the old disk isn't being wiped immediately
5. Wipe the disk (`shred`/`blkdiscard`, or a full-disk encryption key destroy)

---

## 10. Monthly updates

Attended, once a month. Arch has no release day of its own, so the reminder
shares Windows' due date, the day after Patch Tuesday, and one sitting covers
both systems. Day-to-day `paru` runs carry on as before; this is the sweep for
what they don't reach.

**The reminder.** `bootstrap.arch.sh` enables it. On an install that predates
it, once `setup_symlinks.sh` has linked the units in from `symlinks.linux`:

```sh
systemctl --user enable --now update-reminder.timer
```

From the due date until `update.sh` next runs, it shows a notification two
minutes after login, and at noon for a session left open, at most once a day.
It stays on screen until dismissed, and **Update now** opens kitty running the
update. Both scripts keep their state in `~/.local/state/monthly-update`.

**The update.** From a terminal, as your normal user:

```sh
~/MyConfigurations/arch/update.sh
```

It refreshes the mirrorlist with reflector, runs `paru -Syu` (Arch news first),
restarts aria2 if an upgrade (this one or a day-to-day `paru`) replaced its
binary, and walks through new `.pacnew` files with `pacdiff`. Outside pacman
it runs `rustup update`, `go install` for the Brewfile's `go` lines,
`uv python upgrade`, `sheldon lock --update`, vim-plug's `PlugUpgrade` and
`PlugUpdate`, nvim's `Lazy! sync` and `MasonToolsUpdateSync` (headless; the parsers rebuild
themselves the next time nvim starts), and `ya pkg upgrade`, and brings
aria2's installed copies back in line with the repo (restarting aria2 if its
config or unit changed). Then it checks for a newer GE-Proton, that systemd-boot is still first in the boot order,
failed units, orphans and AUR packages that were deleted, and runs the cleanup
below. It ends with what's left, which is some of:

- **Reboot** after a kernel or NVIDIA driver upgrade. The running kernel's
  modules are gone, and GPU programs (Steam, `voice-dictate`'s Vulkan backend)
  fail until the loaded module matches the userspace again. The same goes for
  a day-to-day `paru` that brings either in
- **`.pacnew` files you skipped**: `DIFFPROG='nvim -d' pacdiff --sudo`
- **tmux**: the server keeps running the old version until its last session
  ends, or `tmux kill-server`
- **Reset** the boot order if Windows Update put Windows Boot Manager first:
  `sudo bootctl install` puts systemd-boot back
  ([MIGRATION.windows.md section 4](MIGRATION.windows.md#4-restoring-arch-boot)).
  pacman resets nothing itself, since it writes a `.pacnew` rather than
  replace a config you changed
- **Go tools the Brewfile doesn't list.** `go install` never removes anything,
  so binaries from older lists sit in `~/go/bin` and never update. Delete them
  or add them to the Brewfile
- **GE-Proton**: add the new release in ProtonUp-Qt. Games that pin a version
  by name need switching to it in Steam
- **aria2**: a unit that isn't enabled: `systemctl --user enable --now` it
  ([section 2](#2-clone-and-bootstrap))
- **nvim**: a plugin `Lazy! sync` couldn't update, or a mason package that's
  still behind (`:Mason`, then `U`)
- **vim**: a plugin `PlugUpdate` couldn't update
- **Commit vim-plug** if `PlugUpgrade` replaced `vim/autoload/plug.vim`: in the
  vim submodule, then the submodule in the repo
- **Commit `yazi/package.toml`** if `ya pkg upgrade` moved its revisions. It
  only reaches the repo through its symlink, so the [section 7](#7-known-gotchas)
  drift blocks this step until it's fixed
- **`ya pkg install --discard`** if `ya pkg upgrade` aborted over a plugin
  you never modified. A bump committed on another machine changes the
  recorded hashes, so the plugins still deployed here look locally edited.
  Then run `ya pkg upgrade` again
- **An old uv Python a venv still uses.** The cleanup keeps it and names the
  venv. Recreating the venv moves it onto the minor-version link, and next
  month's cleanup removes the old Python

**The cleanup.** `update.sh` ends with it, and it asks nothing.
`go clean -modcache` empties the Go module cache. Go never prunes it, so it
keeps every version ever downloaded (the first run found 44 of
`golang.org/x/tools`), and each month's `go install @latest` adds another set.
Go projects download what they need again on their next build. The uv Pythons
that `uv python upgrade` replaced are uninstalled: venvs point at the
minor-version link, which moved to the new release, so only a venv made against
the old one directly needs it. `uv cache prune` drops unused uv cache entries.
Run `~/MyConfigurations/arch/cleanup.sh` on its own to free the space sooner.

Left out because they look after themselves: the journal (journald caps it),
`/var/tmp` and coredumps (systemd-tmpfiles), `/tmp` (a tmpfs), and Go's build
cache and Cargo's download cache, which trim themselves. paru deletes its build
folders when `~/.config/paru/paru.conf` has `CleanAfter`. The pacman cache is
pruned by `paccache.timer`, but only once it's set up. On a new install,
`sudo systemctl edit paccache.service` and add:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/paccache -rk2
ExecStart=/usr/bin/paccache -ruk0
```

then `sudo systemctl enable --now paccache.timer`. Weekly, it keeps the two
newest versions of each installed package, enough to downgrade one, and deletes
the downloads of packages that were removed.

**Adding to it.** Each tool is a step file with an update, a cleanup or both:
`unix/steps/` for what macOS runs too, `arch/steps/` for Arch's own.
`unix/runner.zsh` explains the format and the numbering.

**Firmware.** The BIOS is checked from Windows
([MIGRATION.windows.md section 15](MIGRATION.windows.md#15-monthly-updates)).
Microcode, `linux-firmware` and the NVIDIA driver come through pacman.

**Not in the script:** Steam updates itself and its runtime. `reflector.timer`
stays off, because the script refreshes the mirrorlist itself, with the
arguments it was first generated with. `/etc/xdg/reflector/reflector.conf` has
different ones and isn't used.
