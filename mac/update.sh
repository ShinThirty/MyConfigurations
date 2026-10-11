#!/bin/zsh
#
# update.sh — monthly update for macOS, attended (MIGRATION.md section 8).
#
# Updates everything that can be updated from here and ends with what's left
# for you. Finishing records the run, which silences update-reminder.sh until
# the next Patch Tuesday.

[[ "$OSTYPE" == darwin* ]] || { print -u2 "update.sh is macOS-only (got $OSTYPE)"; exit 1 }

DOTFILES=${0:A:h:h}
todo=()

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*" }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*" }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*" }
warn() { printf '  \033[33m⚠️\033[0m  %s\n' "$*" }

# --- Software Update ----------------------------------------------------------
# Automatic updates are on, but they can sit offered for weeks. Installing one
# takes your password and usually a restart, so that part stays in System Settings.
info 'Software Update'
swu=$(softwareupdate --list 2>&1)
major=${$(sw_vers -productVersion)%%.*}
titles=(${(M)${(f)swu}:#*Title: *})
updates=()
for line in $titles; do
  title=${${line#*Title: }%%,*}
  version=${${line#*Version: }%%,*}
  if [[ $title == macOS* && ${version%%.*} != $major ]]; then
    skip "$title is a new major version, not part of the monthly update"
  else
    [[ $title == *$version* ]] || title+=" $version"     # Safari's title has none
    [[ $line == *'Action: restart'* ]] && title+=' (restarts)'
    updates+=($title)
  fi
done
if (( $#updates )); then
  printf '  %s\n' $updates
  open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension'
  print '  Opened System Settings → Software Update: install them there once this has finished'
  todo+=("Software Update: ${(j:, :)updates}")
elif (( $#titles )) || [[ $swu == *'No new software available'* ]]; then
  ok "macOS $(sw_vers -productVersion) is up to date"
else
  warn 'softwareupdate --list failed:'
  print -r -- $swu | sed 's/^/    /'
  todo+=('Software Update: check it in System Settings, softwareupdate --list failed')
fi

# --- Homebrew -----------------------------------------------------------------
info 'Homebrew'
brew update
formulae=(${(f)"$(brew outdated --formula --quiet)"})
casks=(${(f)"$(brew outdated --cask --quiet)"})

# Upgrading a cask replaces its app whether or not it's running, and quits the
# app first when the cask says to (KeePassXC, Webull). Note what's running, to
# reopen what got quit and list what's still on the old version.
running=()
for cask in $casks; do
  for app in ${(M)${(f)"$(brew list --cask $cask)"}:#*.app}; do
    pgrep -qf "/Applications/${app:t}/Contents/MacOS/" && running+=(/Applications/${app:t})
  done
done

brew upgrade || todo+=('brew upgrade stopped on an error: read its output above')

for app in $running; do
  if pgrep -qf "$app/Contents/MacOS/"; then
    todo+=("Restart ${app:t:r}: it's still running the version from before the upgrade")
  elif open -g $app; then
    ok "reopened ${app:t:r}, which the upgrade quit"
  fi
done
# aria2 runs headless from its launch agent (aria2/darwin); restart it on the new binary
if (( ${formulae[(Ie)aria2]} )) && launchctl print gui/$UID/com.aria2 &>/dev/null; then
  launchctl kickstart -k gui/$UID/com.aria2 && ok 'restarted aria2'
fi
if (( ${formulae[(Ie)tmux]} )) && tmux list-sessions &>/dev/null; then
  todo+=('tmux: the server runs the old version until its last session ends (or tmux kill-server)')
fi
brew cleanup --prune=all                        # old versions and every cached download

left=(${(f)"$(brew outdated --quiet)"})
(( $#left )) && todo+=("Still outdated: brew upgrade $left")

# Entries added on another Mac, or never installed on this one
missing=(${(f)"$(brew bundle check --file="$DOTFILES/Brewfile" --verbose 2>&1 |
  sed -n 's/^→ .* \([^ ]*\) needs to be .*/\1/p')"})
(( $#missing )) && todo+=("Not installed from the Brewfile: $missing (brew bundle install --file=$DOTFILES/Brewfile)")

# Mostly deprecated and disabled casks, which brew no longer updates. The
# Command Line Tools warning is left out: Software Update above covers it.
doctor=$(brew doctor 2>&1)
warnings=(${${(M)${(f)doctor}:#Warning: *}#Warning: })
warnings=(${warnings:#*Command Line Tools*})
if (( $#warnings )); then
  print -r -- $doctor | awk '/^Warning: /{ show = !/Command Line Tools/ } show'
  for w in $warnings; do todo+=("brew doctor: $w"); done
else
  ok 'brew doctor has nothing to act on'
fi

# --- Go tools -----------------------------------------------------------------
# brew bundle only installs the Brewfile's go entries. go install @latest
# upgrades them, and rebuilds them with the Go that brew just upgraded.
info 'Go tools'
for pkg in ${(f)"$(sed -n 's/^go "\(.*\)"$/\1/p' "$DOTFILES/Brewfile")"}; do
  if go install "$pkg@latest"; then ok ${pkg:t}; else todo+=("go install $pkg@latest failed"); fi
done

# --- Rust ---------------------------------------------------------------------
info 'Rust toolchain'
if (( $+commands[rustup] )); then rustup update; else skip 'rustup not installed'; fi

# --- zsh plugins --------------------------------------------------------------
# zshrc asks every 14 days on its own; resetting its timer keeps it from asking next
info 'zsh plugins'
export SHELDON_CONFIG_DIR=${SHELDON_CONFIG_DIR:-$DOTFILES/sheldon}
if sheldon lock --update; then
  date +%s >"${XDG_CACHE_HOME:-$HOME/.cache}/sheldon_last_update"
else
  todo+=('sheldon lock --update failed: read its output above')
fi

# --- yazi ---------------------------------------------------------------------
info 'yazi packages'
# A bump pulled from another machine changes package.toml's hashes under the
# plugins deployed here, so ya takes them for local edits and aborts
ya pkg upgrade || todo+=('ya pkg upgrade failed: if it says you modified a plugin you never touched, package.toml was bumped elsewhere: ya pkg install --discard, then ya pkg upgrade')
if [[ -n $(git -C "$DOTFILES" status --porcelain -- yazi/package.toml) ]]; then
  todo+=('Commit the new yazi/package.toml revisions')
fi

# --- Shell PATH ---------------------------------------------------------------
# A macOS update can replace /etc/zprofile or /etc/paths, which decide whether
# Homebrew comes before /usr/bin (MIGRATION.md section 5). Checked in a real
# login shell, as bootstrap.sh does.
info 'Shell PATH'
resolved_git=$(zsh -lic 'command -v git' 2>/dev/null | tr -d '\r')
if [[ $resolved_git == $(brew --prefix)/* ]]; then
  ok "git resolves to $resolved_git"
else
  todo+=("git resolves to ${resolved_git:-nothing} in a login shell, not Homebrew's (MIGRATION.md section 5)")
fi

info 'Left for you'
todo+=('nvim: :Lazy update, then :MasonToolsUpdate and :TSUpdate!' 'vim: :PlugUpdate')
printf '  \033[33m- %s\033[0m\n' $todo

state=~/.local/state/monthly-update
mkdir -p $state
date +%F >$state/last-run
printf '\n\033[32m%s\033[0m\n' "Recorded this month's run; the reminder stays quiet until the next Patch Tuesday"
