# Migrating to a new Mac

Runbook for standing this setup up on a fresh macOS machine. Automated parts are in
`bootstrap.sh` + `Brewfile`; everything else is listed here because it can't be
(or shouldn't be) checked into a public repo.

Rough order: **repo → bootstrap → SSH keys → apps → personal data → verify.**

---

## 1. Clone and bootstrap

```sh
git clone --recursive git@github.com:ShinThirty/MyConfigurations.git ~/MyConfigurations
cd ~/MyConfigurations
./bootstrap.sh
```

> The clone uses SSH, so either do [SSH keys](#2-ssh-keys) first, or clone over
> HTTPS and switch the remote afterwards:
> `git remote set-url origin git@github.com:ShinThirty/MyConfigurations.git`

`bootstrap.sh` is idempotent and never overwrites an existing file. It:

1. Installs Xcode Command Line Tools (re-run the script after the GUI installer finishes)
2. Installs Homebrew and everything in `Brewfile` (formulae, casks, fonts, Go
   tools) — scoped to this repo's own dependencies, so expect a much shorter
   list than the old machine had; [section 3](#3-apps-and-tools-not-covered-by-the-brewfile)
   covers the rest
3. Checks out the `vim/` and `nvim/` submodules
4. Runs `setup_symlinks.sh` (`symlinks` + `symlinks.darwin`)
5. Creates `~/.zprofile`, `~/.zshenv`, `~/.zshrc.local` if missing
6. Runs `ya pkg install` for yazi plugins

Flags: `--no-brew` to skip package installation, `--rust` to also install rustup.

---

## 2. SSH keys

The only secrets this migration covers. Copy these six files from the old Mac
(AirDrop, USB, or `scp` — **not** email or chat):

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

**Alternative to copying:** generate a fresh keypair on the new Mac and add it to
GitHub/sourcehut. If you do that for `signing_key`, you must also append the new
public key to `~/.ssh/allowed_signers` (and keep the old line, or past commits stop
verifying).

---

## 3. Apps and tools not covered by the Brewfile

The `Brewfile` is scoped to what this repo's configs need. Everything below used
to live in it and was removed to keep that scope honest — install what you still
want, skip what you don't.

**Personal apps** — `brew install --cask <name>`:

| Cask | What to redo after install |
|---|---|
| `obsidian` | Vault is in iCloud, see below |
| `microsoft-edge` | Sign in |
| `discord` | Log in |
| `webull` | Log in |
| `shadowsocksx-ng` | Re-enter server config; copy the local rule files (see below) |
| `claude-code@latest` | `claude` CLI; re-auth on first run |

**General CLI** — none of it is referenced by the configs in this repo, so pick
what you actually miss:

```sh
brew install age awscli bottom dive duf fastfetch gh jless jq nano ncdu nmap sd wget
brew install hashicorp/tap/terraform   # needs: brew tap hashicorp/tap
```

`age` is the one with a hard dependency elsewhere — the encryption identity in
[section 4](#4-personal-data-to-bring-over) is useless without it.

**Mac App Store** — sign in with your Apple ID, then Account → Purchased:

- WeChat
- Transocks
- Pages Creator Studio
- Apple iWork / iLife (Pages, Numbers, Keynote, GarageBand, iMovie)

**Direct download:**

- TurboTax (2024, 2025) — reinstall only if you need to open old returns; the
  `.tax20XX` data files live in `~/Documents` and must be copied separately
- 央视频HD

**In the Brewfile but needs setup after install:**

| App | What to redo |
|---|---|
| KeePassXC | Point it at the database (see below) |
| AeroSpace, kitty | Grant **Accessibility** permission in System Settings → Privacy & Security |

---

## 4. Personal data to bring over

None of this is in the repo. Decide case by case what you actually still need.

> This repo is public, so the table below is deliberately generic. Work through
> it against the actual dotfiles in `$HOME` on the old machine — `ls -A ~` is
> the real checklist.

| What | Notes |
|---|---|
| Password manager database | Copy from its local data dir. A second copy lives on the network share; `keepassxc/sync.sh` seeds a missing local copy from there and merges both ways. Its `backups/` dir is disposable. |
| Encryption identity | The age key. Anything encrypted to it is **unrecoverable** without this file — copy it or lose access. |
| Broker / API credential file | Plaintext keys. Copy directly, never into this repo. Rotating them as part of the move is the safer play. |
| Trading working dir | Local SQLite DB plus scratch subdirectories. |
| `~/.aws/config` | Profile definitions only, no secrets. Copy it, then re-authenticate; the `login/cache` and `cli/cache` dirs are disposable. |
| `~/.claude/settings.json` | Claude Code prefs. `projects/`, `sessions/`, `history.jsonl` are per-machine history — copy only if you want it. |
| Obsidian vault | Lives in iCloud Drive, so it **syncs on its own** — sign into iCloud and wait. Don't copy it manually. |
| `~/Documents` | Personal documents, analysis, scripts, tax records. |
| Proxy app rules | The tunneling app's local rule files, under its own dotfile dir. |
| `~/.zsh_history` | Optional, along with the fzf history dir. |

**Regenerate rather than copy:** `~/.rustup`, `~/.cargo`, `~/.npm`, `~/.gradle`,
`~/.ivy2`, `~/.stack`, `~/.cabal`, `~/.ghcup`, `~/go/pkg`, `~/.cache`,
`~/.local/share/sheldon`, `~/.local/share/nvim`. These are caches and toolchains
that rebuild themselves. `~/.battery/` (20 MB of logs) is pure garbage.

If the Haskell (`.ghcup`/`.cabal`/`.stack`) or JVM (`.gradle`/`.ivy2`) trees are
stale, just leave them behind — the generated `~/.zshrc.local` guards the ghcup
source line with a file check, so nothing breaks if ghcup is absent.

---

## 5. Known gotchas

**Dead `core.hooksPath`.** `git/gitconfig` sets
`core.hooksPath = /usr/local/gitconfig/hooks/`, which does not exist on this Mac
either. Git silently finds no hooks, so it's harmless but it also means no hooks
run anywhere. Either recreate that directory on the new machine or delete the
line from `git/gitconfig`.

**Intel vs Apple Silicon Homebrew prefix.** `~/.zprofile` hardcodes a prefix.
`bootstrap.sh` writes whichever one the new machine actually uses
(`/opt/homebrew` on Apple Silicon, `/usr/local` on Intel), but if you copied
`~/.zprofile` from the old Mac by hand, fix it — the wrong prefix breaks every
brew-installed command.

**`brew install git` but `git` is still `/usr/bin/git`.** Homebrew is on PATH,
just ordered after `/usr/bin`. `brew shellenv` no longer prepends to PATH
directly — it runs

```sh
eval "$(/usr/bin/env PATH_HELPER_ROOT="/opt/homebrew" /usr/libexec/path_helper -s)"
```

`path_helper` rebuilds PATH with its own dirs first and everything else
appended. `/etc/zprofile` runs the *system* path_helper, which demotes Homebrew
to the end; `brew shellenv` runs it with the Homebrew root, which promotes
Homebrew back to the front. **Homebrew only wins because `~/.zprofile` is
sourced after `/etc/zprofile`.**

So `brew shellenv` must live in `~/.zprofile` and nowhere earlier. It breaks if:

- it is in `~/.zshenv` — sourced *before* `/etc/zprofile`, so path_helper demotes it
- `/opt/homebrew/bin` was added to `/etc/paths` or `/etc/paths.d/` — path_helper
  orders those after `/usr/bin`
- something appends by hand, e.g. `export PATH="$PATH:/opt/homebrew/bin"`
- the terminal starts a non-login shell, so `~/.zprofile` never runs at all
  (in kitty: `shell zsh --login`)

Diagnose and fix:

```sh
echo $PATH | tr ':' '\n' | head          # /opt/homebrew/bin should be line 1
grep -rn 'brew shellenv' ~/.zshenv ~/.zprofile ~/.zshrc 2>/dev/null
grep -rn 'homebrew' /etc/paths /etc/paths.d/* 2>/dev/null

# correct state — this line in ~/.zprofile, and only there:
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then `exec zsh -l` and confirm `which git` reports `/opt/homebrew/bin/git`.
`bootstrap.sh` sets this up, warns about each of the conflicting cases above,
and verifies the result in a real login shell.

**`~/.config/yazi/package.toml` drift.** On the old Mac this is a real file, not a
symlink (it predated the symlink entry, and `setup_symlinks.sh` skips existing
files), so its pinned plugin revisions have drifted behind the repo's. On a fresh
machine the symlink is created correctly and `ya pkg install` uses the repo's
pins. Nothing to do — just don't copy the old file over.

**GitHub key is RSA.** `~/.ssh/github` is a 4096-bit RSA key with no comment.
Still accepted by GitHub, but a good moment to rotate to ed25519 if you feel like it.

**`gh` is not authenticated** on the old Mac, so there's nothing to migrate. It
is no longer in the Brewfile either — `brew install gh && gh auth login` on the
new one if you want it.

---

## 6. Verification

```sh
exec zsh                                  # sheldon fetches plugins on first run
which fzf fd rg eza bat zoxide yazi delta gitui sheldon
brew bundle check --file=~/MyConfigurations/Brewfile   # should report all satisfied
ls -la ~/.zshrc ~/.gitconfig ~/.config/nvim ~/.config/kitty   # all symlinks into the repo
echo $DOTFILES                            # /Users/<you>/MyConfigurations
```

Then:

- `nvim` — lazy.nvim installs plugins on first launch; `:checkhealth` after
- `vim +PlugInstall +qa`
- `tmux` — prefix keys and gruvbox theme active
- `gitui` in a repo — gruvbox theme, vim keys
- `keys` — opens the cheatsheet
- `git commit` on a scratch change, then `git log --show-signature` to confirm SSH signing
- AeroSpace responds to its keybindings (needs Accessibility permission first)

---

## 7. Decommissioning the old Mac

Once the new machine is verified:

1. Sign out of iCloud, Messages, and the App Store
2. Deauthorize anything license-bound (TurboTax, brokerage apps)
3. Remove the old SSH keys from GitHub and sourcehut **if** you rotated instead of copying
4. Rotate the broker/API keys if the old disk isn't being wiped immediately
5. Erase All Content and Settings
