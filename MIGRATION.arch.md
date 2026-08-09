# Migrating to a new Arch Linux machine

Runbook for standing this setup up on a fresh Arch install. The automated part
is `bootstrap.arch.sh` + `pkglist.arch`; everything else is listed here because
it can't be (or shouldn't be) checked into a public repo.

Rough order: **install Arch → repo → bootstrap → SSH keys → desktop → personal data → verify.**

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
3. Runs `setup_symlinks.sh` (`symlinks`, plus `symlinks.linux` if you add one)
4. Creates `~/.zshenv` and `~/.zshrc.local` if missing
5. Sets the login shell to `/usr/bin/zsh` via `chsh`
6. Runs `ya pkg install` for yazi plugins

Flags: `--no-pkg` to skip package installation, `--rust` to also install rustup,
`--aria2` to install the aria2 systemd user units, `--print-packages` to just
dump the parsed list.

Unlike the macOS script there is no `~/.zprofile` / PATH ordering step —
`/usr/bin` is the only bin dir that matters here, so nothing shadows anything.

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
Nothing in it is macOS-specific, but one line is worth knowing about:

- `core.hooksPath = /usr/local/gitconfig/hooks/` does not exist on either
  machine. Git silently finds no hooks, so it's harmless — but it also means no
  hooks run anywhere. Recreate the directory or delete the line.

Commit signing is SSH-based (`user.signingkey = ~/.ssh/signing_key.pub`,
`gpg.ssh.allowedSignersFile = ~/.ssh/allowed_signers`), so it works as soon as
section 3 is done — no GPG agent or keychain helper involved.

---

## 5. The Hyprland bare repo

The desktop config is **not** in this repo. It lives in a git bare repo at
`~/.dotfiles.git` and currently tracks `~/.config/hypr` only.

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

**`XDG_CONFIG_HOME` is only exported from an interactive zsh.** It's set in
`lib/core/common.zsh`, so any script run before the first zsh login sees it
empty. `aria2/linux/install.sh` writes to `$XDG_CONFIG_HOME/aria2` and would
land in `/aria2` without it — `bootstrap.arch.sh --aria2` passes a default
explicitly, but running `install.sh` by hand from bash does not.

**`aria2/linux/install.sh` uses relative paths.** It copies `../aria2.conf`, so
it only works from inside `aria2/linux/`. Enable the units afterwards:

```sh
systemctl --user enable --now aria2.service
systemctl --user enable --now aria2_update_tracker.timer
```

**Go tools are not in `pkglist.arch`.** The macOS `Brewfile` lists ~22
`go "..."` entries (gopls, dlv, golangci-lint, gofumpt, …) that nvim's Go setup
expects. On Arch they install the same way everywhere:

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

**`symlinks.linux` does not exist yet.** `setup_symlinks.sh` looks for it and
silently skips it. Nothing in the repo is Linux-only today; create the file if
that changes.

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
