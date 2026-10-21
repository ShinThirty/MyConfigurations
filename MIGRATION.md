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
7. Registers the monthly update reminder ([section 8](#8-monthly-updates))

Flags: `--no-brew` to skip package installation, `--rust` to also install rustup.

**Turn off natural scrolling** in System Settings → Mouse, so the wheel scrolls
the same way as on Windows and Arch. macOS has one setting for the mouse and
the trackpad, so this flips the trackpad too. The monthly update checks that
it stays off.

**Settings for AeroSpace and the network share.** Then log out and back in,
which the first one needs:

```sh
# Displays share one set of Spaces, as AeroSpace's guide recommends with more
# than one display: macOS moves a window between Spaces when it changes display,
# which AeroSpace can't follow. The cost: a native-fullscreen app blacks out the
# other display. It also turns off macOS's own window tiling.
defaults write com.apple.spaces spans-displays -bool true
# In case separate Spaces come back: dragging a window to a screen edge or the
# menu bar would tile it over AeroSpace's layout
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
# Mission Control groups windows by app, without which it shows them smaller
# than they need to be
defaults write com.apple.dock expose-group-apps -bool true
# No .DS_Store files on tp-share, where Windows and Arch see them
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
```

All but the last are in System Settings → Desktop & Dock. The monthly update
checks these too.

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
| `clash-verge-rev` | Import the subscription or profile (see below). Install Service Mode in its settings and turn on TUN mode, so terminal tools (brew, `go install`, git) go through it too, not just apps that follow the system proxy. Set it up before a trip to mainland China — fetching it from there is the hard part |
| `claude-code@latest` | `claude` CLI; re-auth on first run. Restoring `settings.json` from the `~/.claude/` row below brings back `"env": { "DISABLE_AUTOUPDATER": "1" }`, which stops its own update checks — the monthly `brew upgrade` handles updates |

**General CLI** — none of it is referenced by the configs in this repo, so pick
what you actually miss:

```sh
brew install age awscli bottom dive duf fastfetch gh jless jq nano ncdu nmap sd wget
brew install hashicorp/tap/terraform   # needs: brew tap hashicorp/tap
```

`age` is the one with a hard dependency elsewhere — the encryption identity in
[section 4](#4-personal-data-to-bring-over) is useless without it.

**In the Brewfile but needs setup after install:**

| App | What to redo |
|---|---|
| KeePassXC | Open the database (see below). Then Settings → Browser Integration → turn it on and tick **Edge**, which writes Edge's native-messaging manifest, and connect the KeePassXC-Browser extension, which Edge sync brings back |
| AeroSpace, kitty | Grant **Accessibility** permission in System Settings → Privacy & Security |
| aria2 | Its daemon and tracker updates need an install of their own (below) |
| findutils (`locate`) | Run `loaddb` once. `locate` searches `~/locatedb`, which only `loaddb` builds (your home folder, minus `/Volumes`), and nothing rebuilds it on a schedule — run it again when results are stale |

**aria2.** `aria2/darwin/install.sh` copies `aria2.conf` and the tracker
script into `~/.config/aria2/`, and two launch agents into
`~/Library/LaunchAgents/`: `com.aria2` runs aria2 at login and keeps it running,
and `com.aria2.regular.tracker.update` refreshes its BitTorrent trackers on
Fridays at 11:30. The script creates an empty `aria2.session` only if none
exists, so to resume unfinished downloads, copy the old Mac's
`~/.config/aria2/aria2.session` there first — once aria2 runs, it rewrites the
file every minute. The script uses relative paths, so run it from its folder,
and from zsh: it writes to `$XDG_CONFIG_HOME`, which only an interactive zsh
exports.

```sh
cd ~/MyConfigurations/aria2/darwin && bash install.sh
launchctl load ~/Library/LaunchAgents/com.aria2.plist
launchctl load ~/Library/LaunchAgents/com.aria2.regular.tracker.update.plist
~/.config/aria2/aria2_update_tracker.sh   # trackers now: the repo's aria2.conf has none
curl -s localhost:6800/jsonrpc -d '{"jsonrpc":"2.0","id":1,"method":"aria2.getVersion"}'
```

The plists hardcode `/Users/shinthirty` and `/opt/homebrew`, so under another
user name or on an Intel Mac, fix them in the repo first. The installed files
are copies, since the tracker refresh rewrites `aria2.conf`. The monthly update
([section 8](#8-monthly-updates)) brings them back in line with the repo,
keeping only the tracker line, so a local edit to them doesn't last. Downloads go to
`~/Downloads`; for incoming BitTorrent peers, forward 6881–6999 on the router.
`aria2/README.md` covers the AriaNg frontend and the browser extension.

**IdeaVim.** `bootstrap.sh` links `~/.ideavimrc`, which matters once a
JetBrains IDE is installed. Install the **IdeaVim** and **Which-Key** plugins
from the IDE's Marketplace: the config's `set which-key` needs the second for
its key-binding popup. The other plugins it loads (surround, commentary,
NERDTree, …) are built into IdeaVim.

---

## 4. Personal data to bring over

None of this is in the repo. Decide case by case what you actually still need.

> This repo is public, so the table below is deliberately generic. Work through
> it against the actual dotfiles in `$HOME` on the old machine — `ls -A ~` is
> the real checklist.

| What | Notes |
|---|---|
| Password manager database | `~/.local/share/keepass/*.kdbx`, then open it in KeePassXC. A second copy lives on the network share, and `keepassxc/sync.sh` merges the two both ways — but it looks only at that path, so with the database anywhere else it seeds a second local copy from the share, and the two drift apart. Its `backups/` dir is disposable. |
| Encryption identity | The age key. Anything encrypted to it is **unrecoverable** without this file — copy it or lose access. |
| Broker / API credential file | Plaintext keys. Copy directly, never into this repo. Rotating them as part of the move is the safer play. |
| Trading working dir | Local SQLite DB plus scratch subdirectories. |
| `~/.aws/config` | Profile definitions only, no secrets. Copy it, then re-authenticate; the `login/cache` and `cli/cache` dirs are disposable. |
| `~/.claude/settings.json` | Claude Code prefs. `projects/`, `sessions/`, `history.jsonl` are per-machine history — copy only if you want it. |
| Obsidian vault | Lives in iCloud Drive, so it **syncs on its own** — sign into iCloud and wait. Don't copy it manually. |
| `~/Documents` | Personal documents, analysis, scripts, tax records. |
| `~/Music/playlists/` | Plain-text playlists the `music` function reads. Small, easy to forget. |
| Proxy client profiles | Clash Verge Rev's profiles, under its Application Support dir. They hold server credentials — copy them, or re-import from the subscription URL. |
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
- `music` — playlist picker comes up (needs `~/Music/playlists/`)
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

---

## 8. Monthly updates

Attended, once a month. Apple ships on no fixed day, so the Mac borrows the
Windows box's schedule: due the day after Patch Tuesday, the second Tuesday,
and both machines come due together.

**The reminder.** `bootstrap.sh` registers it; to do it by hand, or again after
moving the repo:

```sh
~/MyConfigurations/mac/update-reminder.sh --register
```

That writes `~/Library/LaunchAgents/local.monthly-update-reminder.plist`, which
macOS announces as a background item from zsh. From the due day until
`update.sh` next runs, it posts a notification at login, and at noon for a Mac
left on, at most once a day. The notification comes from Script Editor: allow
it the first time, and set Script Editor's style to **Alerts** in System
Settings → Notifications so it stays until dismissed. Clicking it opens Script
Editor, so dismiss it instead. Both scripts keep their state in
`~/.local/state/monthly-update`.

**The update.**

```sh
~/MyConfigurations/mac/update.sh
```

It lists what Software Update has and opens it in System Settings, runs
`brew upgrade`, reinstalls the Brewfile's Go tools at `@latest`, runs
`rustup update`, `uv python upgrade` (once uv has Pythons of its own),
`sheldon lock --update`, vim-plug's `PlugUpgrade` and `PlugUpdate`, nvim's
`Lazy! sync` and `MasonToolsUpdateSync` (headless; the parsers rebuild
themselves the next time nvim starts), and `ya pkg upgrade`, brings aria2's
installed copies back in line with the repo (restarting aria2 if its config
changed), checks the Brewfile against what's installed and reads `brew doctor`, checks that `git`
still resolves to Homebrew's in a login shell and that the settings from
section 1 are still as set, and runs the cleanup below. It ends with what's left, which is
some of:

- **Software Update** — automatic updates are on, but they can sit offered for
  weeks. Installing takes your password and usually a restart, so it stays in
  System Settings; do it after the script finishes. A new major version is
  listed but left out — that's a decision, not a chore
- **Apps that were running** — upgrading a cask replaces the app even while it
  runs, and the old version keeps running until restarted. kitty is the usual
  one, since the script runs in it. The script reopens an app whose cask quits
  it to upgrade, like KeePassXC
- **Not installed from the Brewfile** — an entry added on another Mac, or never
  installed on this one: `brew bundle install --file=Brewfile`
- **brew doctor** — mostly deprecated and disabled casks, which brew no longer
  updates. The Command Line Tools warning is left out, since Software Update
  covers it
- **tmux** — the server keeps running the old version until its last session ends
- **Go tools the Brewfile doesn't list** — `go install` never removes anything,
  so binaries from older lists sit in `~/go/bin` and never update. Delete them
  or add them to the Brewfile
- **nvim** — a plugin `Lazy! sync` couldn't update, or a mason package that's
  still behind (`:Mason`, then `U`). nvim exits 0 whatever happens, so the
  script reads its output and asks mason afterwards
- **vim** — a plugin `PlugUpdate` couldn't update. vim clears the screen when
  it quits, so the script saves `PlugUpdate`'s report first and prints the
  failures from it
- **Commit vim-plug** if `PlugUpgrade` replaced `vim/autoload/plug.vim`: in the
  vim submodule, then the submodule in the repo
- **Commit `yazi/package.toml`** if `ya pkg upgrade` moved its revisions. It
  only reaches the repo through its symlink, so the
  [section 5](#5-known-gotchas) drift blocks this step until it's fixed
- **`ya pkg install --discard`** if `ya pkg upgrade` aborted over a plugin
  you never modified. A bump committed on another machine changes the
  recorded hashes, so the plugins still deployed here look locally edited.
  Then run `ya pkg upgrade` again
- **aria2** — a launch agent that isn't loaded: `launchctl load` it
  ([section 3](#3-apps-and-tools-not-covered-by-the-brewfile))
- **Reset** — something a macOS update turned back: the PATH order
  ([section 5](#5-known-gotchas)), or a setting from this runbook, such as
  natural scrolling ([section 1](#1-clone-and-bootstrap))

**The cleanup.** `update.sh` ends with it, and it asks nothing:
`brew cleanup --prune=all` removes old versions and every cached download,
`go clean -modcache` empties the Go module cache, and `uv cache prune` drops
unused uv cache entries. Once uv has Pythons of its own, it also uninstalls the
ones `uv python upgrade` replaced, as on Arch. Go never prunes its module
cache, so it keeps every version ever downloaded, and each month's
`go install @latest` adds another set; Go projects download what they need
again on their next build. Run
`~/MyConfigurations/mac/cleanup.sh` on its own to free the space sooner. Left
out because they look after themselves: macOS clears its temp folder, Go trims
its build cache, and Edge's updater deletes its old installers from
`~/Library/Application Support/Microsoft/EdgeUpdater`.

`zsh/zshrc` still offers a sheldon update every 14 days; `update.sh` resets its
timer.

**Adding to it.** Each tool is a step file with an update, a cleanup or both:
`unix/steps/` for what Arch runs too, `mac/steps/` for the Mac's own.
`unix/runner.zsh` explains the format and the numbering. A setting you make by
hand goes in the table in `mac/steps/80-settings.zsh`, so the update notices
when macOS resets it.

**Not in the script, because they update themselves:** Edge, Discord,
Obsidian and Clash Verge Rev (their casks are marked `auto_updates`, which
`brew upgrade` skips),
App Store apps, and the firmware, which comes with macOS updates. KeePassXC
has its own update check off, so brew is the only thing that updates it —
keep it that way if a restored config turns it back on.
