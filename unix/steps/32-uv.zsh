# uv's own Pythons, and its cache

update() {
  info 'uv-managed Pythons'
  (( $+commands[uv] )) || { skip 'uv not installed'; return }
  local pythons=($(uv python dir 2>/dev/null)/*(N/))
  (( $#pythons )) || { skip 'none installed'; return }
  # Venvs point at the minor-version directory, so they pick up the new patch
  # release. The cleanup uninstalls the one it replaces
  uv python upgrade || todo+=('uv python upgrade failed: read its output above')
}

cleanup() {
  info 'Cleanup: superseded uv Pythons'
  (( $+commands[uv] )) || { skip 'uv not installed'; return }
  # uv python upgrade installs the new patch release beside the old one and moves
  # the minor-version link that venvs point at. The old one stays only for a venv
  # made against it directly, which would break without it.
  local pydir=$(uv python dir 2>/dev/null) name out
  # cpython-3.13.13-linux-x86_64-gnu: the series is everything but the patch
  # number. Sorted numerically, so the last one in each series is the newest
  local re='^([a-z]+-[0-9]+\.[0-9]+)\.[0-9a-z]+(.*)$' pythons=($pydir/*(N/n:t))
  local -A newest
  for name in $pythons; do
    [[ $name =~ $re ]] && newest[$match[1]$match[2]]=$name
  done
  local old=() venvs=() users=() remove=()
  for name in $pythons; do
    [[ $name =~ $re && $newest[$match[1]$match[2]] != $name ]] && old+=($name)
  done
  # ~/Library is skipped: no venv lives there, and macOS asks before a terminal
  # reads most of it
  (( $#old )) && venvs=(${(f)"$(find $HOME -xdev -path $HOME/Library -prune -o \
    -name pyvenv.cfg -not -path "$pydir/*" -print 2>/dev/null)"})
  for name in $old; do
    users=()
    (( $#venvs )) && users=(${(f)"$(grep -lF $pydir/$name/ $venvs)"})
    if (( $#users )); then
      todo+=("$name stays for the venvs made against it; recreate them to move them onto the minor-version link: ${users%/pyvenv.cfg}")
    else
      remove+=($name)
    fi
  done
  if (( $#remove )); then
    # uv reports on stderr. Captured, so a failure's cause makes it into the summary
    out=$(uv python uninstall $remove 2>&1) || todo+=("uv python uninstall failed: ${out##*$'\n'}")
    print -r -- $out | sed 's/^/  /'
  else
    skip 'none'
  fi

  info 'Cleanup: uv cache'
  out=$(uv cache prune 2>&1) || todo+=("uv cache prune failed: ${out##*$'\n'}")
  print -r -- $out | sed 's/^/  /'
}
