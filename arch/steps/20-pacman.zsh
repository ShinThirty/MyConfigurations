# Mirrors, system and AUR packages, and the config files their upgrades replace

update() {
  info 'Mirrors'
  # The arguments this machine's mirrorlist was generated with. reflector.conf,
  # which reflector.service reads, has different ones and isn't used.
  if sudo reflector --protocol https --country 'United States' --latest 20 --sort rate \
       --save /etc/pacman.d/mirrorlist; then
    ok 'mirrorlist refreshed'
  else
    warn 'reflector failed, so the old mirrorlist stays'
  fi

  # paru.conf has NewsOnUpgrade (Arch news before the upgrade), Devel (-git
  # packages) and SudoLoop
  info 'System and AUR packages'
  paru -Syu || todo+=("paru -Syu didn't finish; run it again")

  info 'Config files from upgrades (.pacnew, .pacsave)'
  local pacfiles=(${(f)"$(pacdiff --output)"})
  if (( ! $#pacfiles )); then
    skip 'none'
    return
  fi
  # --sudo goes through sudoedit, so nvim runs as you with your config. v opens
  # the pair (edit the original, :wqa), then r removes the .pacnew; o takes the
  # .pacnew whole; s skips.
  DIFFPROG='nvim -d' pacdiff --sudo
  pacfiles=(${(f)"$(pacdiff --output)"})
  (( $#pacfiles )) && todo+=("Still unmerged, for DIFFPROG='nvim -d' pacdiff --sudo: $pacfiles")
}
