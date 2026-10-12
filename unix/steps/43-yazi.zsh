# yazi's plugins and flavors, pinned in yazi/package.toml

update() {
  info 'yazi packages'
  (( $+commands[ya] )) || { skip 'yazi not installed'; return }
  # ya writes to ~/.config/yazi/package.toml, which reaches the repo only through its symlink
  if [[ ! -L $HOME/.config/yazi/package.toml ]]; then
    warn "yazi's package.toml is a copy, not the repo's symlink"
    todo+=("yazi: swap ~/.config/yazi/package.toml for the repo's symlink (the runbook's known gotchas), then ya pkg upgrade")
    return
  fi
  # A bump pulled from another machine changes package.toml's hashes under the
  # plugins deployed here, so ya takes them for local edits and aborts
  ya pkg upgrade || todo+=('ya pkg upgrade failed: if it says you modified a plugin you never touched, package.toml was bumped elsewhere: ya pkg install --discard, then ya pkg upgrade')
  [[ -z $(git -C $DOTFILES status --porcelain -- yazi/package.toml) ]] ||
    todo+=('Commit the new yazi/package.toml revisions')
}
