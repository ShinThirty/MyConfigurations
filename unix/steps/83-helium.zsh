# Helium's new tab links, in ~/.config/helium-newtab/links.js, against the
# sites its history says you open: helium/newtab-links.sh lists the sites to
# add a link for and the links to drop

update() {
  info "Helium's new tab"
  [[ -d /Applications/Helium.app ]] || (( $+commands[helium-browser] )) ||
    { skip 'not installed'; return }
  local out
  if ! out=$($DOTFILES/helium/newtab-links.sh); then
    warn "couldn't read Helium's history"
    return
  fi
  local lines=(${(f)out})
  if (( $#lines )); then
    warn 'links to add or drop, listed below'
    todo+=("Helium's new tab: "${^lines})
  else
    ok 'its links are the sites you open'
  fi
}
