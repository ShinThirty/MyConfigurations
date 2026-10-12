# Failed units, orphaned packages, and AUR packages that were deleted

update() {
  info 'Health'
  local health=()
  local units=(${(f)"$({ systemctl --failed --plain --no-legend; systemctl --user --failed --plain --no-legend } |
    awk '{ print $1 }')"})
  (( $#units )) && health+=("Failed units, see systemctl status: $units")

  local orphans=(${(f)"$(pacman -Qdtq)"})
  (( $#orphans )) &&
    health+=("Orphans, which nothing depends on: $orphans — sudo pacman -Rns \$(pacman -Qdtq)")

  # An AUR package that's been deleted stops getting updates without a word from paru
  local foreign=(${(f)"$(pacman -Qmq)"}) found=() gone=()
  if (( $#foreign )); then
    found=(${(f)"$(paru -Sia $foreign 2>/dev/null | awk '/^Name/ { print $3 }')"})
    if (( $#found )); then
      gone=(${foreign:|found})
      (( $#gone )) && health+=("Gone from the AUR, so never updated again: $gone")
    else
      warn "couldn't reach the AUR to check for deleted packages"
    fi
  fi

  if (( $#health )); then
    warn "$#health found, listed below"
    todo+=($health)
  else
    ok 'no failed units, orphans or deleted AUR packages'
  fi
}
