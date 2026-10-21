# Homebrew's formulae and casks, the Brewfile, and what brew keeps around

update() {
  info 'Homebrew'
  brew update
  local formulae=(${(f)"$(brew outdated --formula --quiet)"})
  local casks=(${(f)"$(brew outdated --cask --quiet)"})

  # Upgrading a cask replaces its app whether or not it's running, and quits the
  # app first when the cask says to (KeePassXC). Note what's running, to
  # reopen what got quit and list what's still on the old version.
  local running=() cask app
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
  local left=(${(f)"$(brew outdated --quiet)"})
  (( $#left )) && todo+=("Still outdated: brew upgrade $left")

  # Entries added on another Mac, or never installed on this one
  local missing=(${(f)"$(brew bundle check --file="$DOTFILES/Brewfile" --verbose 2>&1 |
    sed -n 's/^→ .* \([^ ]*\) needs to be .*/\1/p')"})
  (( $#missing )) && todo+=("Not installed from the Brewfile: $missing (brew bundle install --file=$DOTFILES/Brewfile)")

  # Mostly deprecated and disabled casks, which brew no longer updates. The
  # Command Line Tools warning is left out: Software Update above covers it.
  local doctor=$(brew doctor 2>&1) w
  local warnings=(${${(M)${(f)doctor}:#Warning: *}#Warning: })
  warnings=(${warnings:#*Command Line Tools*})
  if (( $#warnings )); then
    print -r -- $doctor | awk '/^Warning: /{ show = !/Command Line Tools/ } show'
    for w in $warnings; do todo+=("brew doctor: $w"); done
  else
    ok 'brew doctor has nothing to act on'
  fi
}

cleanup() {
  info 'Cleanup: Homebrew'
  # Old versions and every cached download. Captured, so a failure's cause makes
  # it into the summary
  local out
  out=$(brew cleanup --prune=all 2>&1) || todo+=("brew cleanup failed: ${out##*$'\n'}")
  print -r -- ${out:-Nothing to remove} | sed 's/^/  /'
}
