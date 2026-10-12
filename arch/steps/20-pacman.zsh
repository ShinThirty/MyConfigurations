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

  # An upgrade replaces a binary under the process running it, which keeps the
  # old version until restarted: /proc shows its exe as deleted. Checked rather
  # than this run's upgrades, so a day-to-day paru's are caught too.
  # aria2 runs headless from its user service (aria2/linux); restart it on the new binary
  local pid
  pid=$(systemctl --user show --property MainPID --value aria2.service 2>/dev/null)
  if (( pid )) && [[ $(readlink /proc/$pid/exe) == *' (deleted)' ]]; then
    systemctl --user restart aria2.service && ok 'restarted aria2 on the new version'
  fi
  for pid in ${(f)"$(pgrep -u $UID -x 'tmux: server')"}; do
    if [[ $(readlink /proc/$pid/exe) == *' (deleted)' ]]; then
      todo+=('tmux: the server runs the old version until its last session ends (or tmux kill-server)')
      break
    fi
  done

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
