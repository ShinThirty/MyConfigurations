# GE-Proton, which ProtonUp-Qt installs, and only when asked

update() {
  info 'GE-Proton'
  local compat=$HOME/.local/share/Steam/compatibilitytools.d latest
  local installed=($compat/GE-Proton*(Nn:t))     # numerically, so the newest is last
  (( $#installed )) || { skip 'none installed'; return }
  latest=$(curl -fsS -o /dev/null -w '%{redirect_url}' \
    https://github.com/GloriousEggroll/proton-ge-custom/releases/latest)
  latest=${latest##*/}
  if [[ -z $latest ]]; then
    warn "couldn't look up the latest release"
  elif [[ -d $compat/$latest ]]; then
    ok "$latest, the latest"
  else
    warn "$latest is out; the newest here is $installed[-1]"
    todo+=("GE-Proton: add $latest in ProtonUp-Qt, then move games that pin $installed[-1] onto it")
  fi
}
