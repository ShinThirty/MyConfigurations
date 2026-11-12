# KooL's Hyprland-Dots, which make up ~/.config/hypr: a newer release, and
# whether the Hyprland that paru installed still loads the config. Upgrading is
# arch/kooldots-upgrade.sh's job and attended (MIGRATION.arch.md section 5), so
# this only adds it to the todo.

update() {
  info "KooL's Hyprland-Dots"
  local hypr=${XDG_CONFIG_HOME:-$HOME/.config}/hypr
  local dots=$HOME/Arch-Hyprland/Hyprland-Dots
  if (( ! $+commands[Hyprland] )) || [[ ! -d $dots/.git ]]; then
    skip 'not set up here'
    return
  fi

  # The dots ship a file named for their version, such as v2.3.28.3. Each
  # release is a Hyprland-Dots-v* tag; main moves on between them.
  local installed=($hypr/v<->.*(Nn.:t)) out tags=()
  if out=$(capped 30 env GIT_TERMINAL_PROMPT=0 \
             git -C $dots ls-remote --tags --refs origin 'Hyprland-Dots-v*' 2>/dev/null); then
    tags=(${(n)${${(f)out}##*/Hyprland-Dots-}})
  fi
  if (( ! $#tags )); then
    warn "couldn't look up KooL's releases"
  elif (( ! $#installed )); then
    warn "no version file in ${hypr/#$HOME/~}, so the release there is unknown; KooL's latest is $tags[-1]"
  elif [[ $installed[-1] == $tags[-1] ]]; then
    ok "$tags[-1], the latest"
  else
    local i=${tags[(Ie)$installed[-1]]} behind=''
    if (( i )); then
      behind=", $(( $#tags - i )) release"
      (( $#tags - i > 1 )) && behind+=s
      behind+=' behind'
    fi
    warn "$tags[-1] is out; this has $installed[-1]$behind"
    todo+=("KooL's Hyprland-Dots: upgrade to $tags[-1] with arch/kooldots-upgrade.sh, then log out and back in (MIGRATION.arch.md section 5)")
  fi

  # A made-up instance, so nothing the check runs can reach the session's socket
  out=$(capped 60 env HYPRLAND_INSTANCE_SIGNATURE=monthly-update-check Hyprland --verify-config 2>&1)
  if [[ $out == *'Regular config at '*/hyprland.lua* ]] && (( ${${(f)out}[(Ie)config ok]} )); then
    ok 'Hyprland loads the config, from hyprland.lua'
  else
    print -rl -- '    '${^${(f)out}[-5,-1]}
    todo+=("Hyprland: --verify-config fails on ${hypr/#$HOME/~}, or doesn't pick hyprland.lua; see above. A newer KooL release may fix it: arch/kooldots-upgrade.sh (MIGRATION.arch.md section 5)")
  fi
}
