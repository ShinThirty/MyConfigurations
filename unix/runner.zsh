# runner.zsh — the part of the monthly update and cleanup that macOS and Arch
# share (MIGRATION.md section 8, MIGRATION.arch.md section 10). Sourced by
# mac/update.sh, mac/cleanup.sh, arch/update.sh and arch/cleanup.sh, after they
# set $DOTFILES.
#
# Each tool is a step: a file named NN-tool.zsh, in unix/steps/ when both
# platforms run it, or in mac/steps/ or arch/steps/. A step defines update(),
# cleanup() or both, and nothing else, since it's sourced once per phase. It
# skips itself when its tool isn't installed, reports through the helpers
# below, and adds what it leaves for you to todo. Its variables are local, so
# they don't leak into the next step.
#
# The number sets the order, and a tool keeps its number on every platform:
# 10 the OS, 20 the package manager, 3x toolchains, 4x shell and editor
# plugins, 5x the platform's own extras, 8x checks.

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*" }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*" }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*" }
warn() { printf '  \033[33m⚠️\033[0m  %s\n' "$*" }

todo=()

# run_steps <platform> <phase>...: every step's update or cleanup, by number
run_steps() {
  local platform=$1 phase step
  shift
  local steps=($DOTFILES/(unix|$platform)/steps/*.zsh(N.oe['REPLY=${REPLY:t}']))
  for phase; do
    for step in $steps; do
      unfunction update cleanup 2>/dev/null
      source $step
      (( $+functions[$phase] )) && $phase
    done
  done
  unfunction update cleanup 2>/dev/null
}

left_for_you() {
  (( $#todo )) || return 0
  info 'Left for you'
  printf '  \033[33m- %s\033[0m\n' $todo
}
