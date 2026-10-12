#!/usr/bin/env bash
#
# Monthly cleanup (MIGRATION.arch.md section 10). update.sh runs it last; run it
# on its own to free the space sooner. What looks after itself (the pacman
# cache, paru's builds, the journal, temp dirs, Go's build cache) isn't here.

# Sourced by update.sh, it adds to that script's list of what's left for you;
# run on its own, it prints its own
standalone=0
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  standalone=1
  set -uo pipefail
  todo=()
fi

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*"; }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*"; }

# --- Go module cache ----------------------------------------------------------
# Go never prunes it, so it keeps every version ever downloaded, and each
# month's go install @latest adds another set. Go projects download what they
# need again on their next build.
info 'Cleanup: Go module cache'
modcache="$(go env GOMODCACHE 2>/dev/null)"
if [[ ! -d $modcache ]]; then
  skip 'empty'
else
  kb="$(du -sk "$modcache" | cut -f1)"
  if go clean -modcache; then
    ok "removed $(( kb / 1024 )) MB from ${modcache/#"$HOME"/\~}"
  else
    todo+=('go clean -modcache failed: read its output above')
  fi
fi

# --- Superseded uv Pythons ----------------------------------------------------
# uv python upgrade installs the new patch release beside the old one and moves
# the minor-version link that venvs point at. The old one stays only for a venv
# made against it directly, which would break without it.
info 'Cleanup: superseded uv Pythons'
pydir="$(uv python dir 2>/dev/null)"
# cpython-3.13.13-linux-x86_64-gnu: the series is everything but the patch number
re='^([a-z]+-[0-9]+\.[0-9]+)\.[0-9a-z]+(.*)$'
declare -A newest=()
mapfile -t pythons < <(find "$pydir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V)
for name in "${pythons[@]}"; do
  [[ $name =~ $re ]] && newest["${BASH_REMATCH[1]}${BASH_REMATCH[2]}"]="$name"
done
mapfile -t venvs < <(find "$HOME" -xdev -name pyvenv.cfg -not -path "$pydir/*" 2>/dev/null)
old=()
for name in "${pythons[@]}"; do
  [[ $name =~ $re ]] || continue
  [[ ${newest["${BASH_REMATCH[1]}${BASH_REMATCH[2]}"]} != "$name" ]] || continue
  users=()
  (( ${#venvs[@]} )) && mapfile -t users < <(grep -lF "$pydir/$name/" "${venvs[@]}")
  if (( ${#users[@]} )); then
    todo+=("$name stays for the venvs made against it; recreate them to move them onto the minor-version link: ${users[*]%/pyvenv.cfg}")
  else
    old+=("$name")
  fi
done
if (( ${#old[@]} )); then
  # uv reports on stderr. Captured, so a failure's cause makes it into the summary
  out="$(uv python uninstall "${old[@]}" 2>&1)" || todo+=("uv python uninstall failed: ${out##*$'\n'}")
  printf '%s\n' "$out" | sed 's/^/  /'
else
  skip 'none'
fi

# --- uv cache -----------------------------------------------------------------
info 'Cleanup: uv cache'
out="$(uv cache prune 2>&1)" || todo+=("uv cache prune failed: ${out##*$'\n'}")
printf '%s\n' "$out" | sed 's/^/  /'

if (( standalone && ${#todo[@]} )); then
  info 'Left for you'
  printf '  \033[33m-\033[0m %s\n' "${todo[@]}"
fi
