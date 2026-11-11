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

# capped <seconds> <command>...: runs the command, and if it runs past <seconds>
# stops it along with what it started and returns 124, as timeout(1) does
# (macOS has none). Its stdout and stderr reach the caller once it ends, through
# files, so a process it started can't hold the caller's $(...) open
capped() {
  setopt localoptions localtraps
  local limit=$1 dir=$(mktemp -d) pid st start=$SECONDS
  shift
  # In the background, so this shell can watch the clock
  "$@" >$dir/out 2>$dir/err &
  pid=$!
  trap 'kill_tree $pid; command rm -rf $dir; exit 130' INT TERM
  while kill -0 $pid 2>/dev/null && (( SECONDS - start < limit )); do
    sleep 0.2
  done
  if kill -0 $pid 2>/dev/null; then
    kill_tree $pid
    wait $pid 2>/dev/null
    st=124
  else
    wait $pid 2>/dev/null
    st=$?
  fi
  cat $dir/out
  cat $dir/err >&2
  command rm -rf $dir
  return $st
}

# kill_tree <pid>: kills the process and everything it started
kill_tree() {
  local tree=() kids=($1)
  while (( $#kids )); do
    tree+=($kids)
    kids=($(pgrep -P ${(j:,:)kids}))
  done
  kill -KILL $tree 2>/dev/null
}

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
