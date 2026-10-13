# What a macOS update can quietly reset: the login shell's PATH, and the
# settings MIGRATION.md has you make by hand

update() {
  info 'Settings'
  local drift=()
  # A macOS update can replace /etc/zprofile or /etc/paths, which decide whether
  # Homebrew comes before /usr/bin (MIGRATION.md section 5). Checked in a real
  # login shell, as bootstrap.sh does.
  local resolved=$(zsh -lic 'command -v git' 2>/dev/null | tr -d '\r')
  [[ $resolved == $(brew --prefix)/* ]] ||
    drift+=("git resolves to ${resolved:-nothing} in a login shell, not Homebrew's (MIGRATION.md section 5)")

  # Domain, key, the value defaults should read, and what to do when it doesn't
  local settings=(
    NSGlobalDomain com.apple.swipescrolldirection 0
    'natural scrolling is on again: turn it off in System Settings → Mouse (MIGRATION.md section 1)'
    com.apple.spaces spans-displays 1
    'displays have separate Spaces again: turn it off in System Settings → Desktop & Dock, then log out (MIGRATION.md section 1)'
    com.apple.WindowManager EnableTilingByEdgeDrag 0
    'dragging a window to a screen edge tiles it again: turn it off in System Settings → Desktop & Dock (MIGRATION.md section 1)'
    com.apple.WindowManager EnableTopTilingByEdgeDrag 0
    'dragging a window to the menu bar fills the screen again: turn it off in System Settings → Desktop & Dock (MIGRATION.md section 1)'
    com.apple.dock expose-group-apps 1
    'Mission Control no longer groups windows by app: turn it on in System Settings → Desktop & Dock (MIGRATION.md section 1)'
    com.apple.desktopservices DSDontWriteNetworkStores 1
    'Finder writes .DS_Store files to network shares again (MIGRATION.md section 1): defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
  )
  local domain key want fix
  for domain key want fix in $settings; do
    [[ $(defaults read $domain $key 2>/dev/null) == $want ]] || drift+=($fix)
  done

  if (( $#drift )); then
    warn "$#drift changed, listed below"
    todo+=("Reset: "${^drift})
  else
    ok "git resolves to $resolved; the settings MIGRATION.md makes are as set"
  fi
}
