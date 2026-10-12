#!/bin/zsh
#
# cleanup.sh — monthly cleanup for macOS (MIGRATION.md section 8).
#
# update.sh runs it last; run it on its own to free the space sooner. macOS
# clears its own temp folder and Go trims its build cache, so neither is here.

[[ "$OSTYPE" == darwin* ]] || { print -u2 "cleanup.sh is macOS-only (got $OSTYPE)"; exit 1 }

# Sourced by update.sh, it adds to that script's list of what's left for you;
# run on its own, it prints its own
standalone=$(( ! ${+todo} ))
(( standalone )) && todo=()

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*" }
ok()   { printf '  \033[32m✅\033[0m %s\n' "$*" }
skip() { printf '  \033[90m•\033[0m  %s\n' "$*" }

# --- Homebrew -----------------------------------------------------------------
info 'Cleanup: Homebrew'
# Old versions and every cached download. Captured, so a failure's cause makes
# it into the summary
out=$(brew cleanup --prune=all 2>&1) || todo+=("brew cleanup failed: ${out##*$'\n'}")
print -r -- ${out:-Nothing to remove} | sed 's/^/  /'

# --- Go module cache ----------------------------------------------------------
# Go never prunes it, so it keeps every version ever downloaded, and each
# month's go install @latest adds another set. Go projects download what they
# need again on their next build.
info 'Cleanup: Go module cache'
modcache=$(go env GOMODCACHE 2>/dev/null)
if [[ ! -d $modcache ]]; then
  skip 'empty'
else
  kb=$(du -sk $modcache | cut -f1)
  if go clean -modcache; then
    ok "removed $(( kb / 1024 )) MB from ${modcache/#$HOME/~}"
  else
    todo+=('go clean -modcache failed: read its output above')
  fi
fi

# --- uv cache -----------------------------------------------------------------
info 'Cleanup: uv cache'
# uv reports on stderr. Captured, like brew's
out=$(uv cache prune 2>&1) || todo+=("uv cache prune failed: ${out##*$'\n'}")
print -r -- $out | sed 's/^/  /'

if (( standalone && $#todo )); then
  info 'Left for you'
  printf '  \033[33m- %s\033[0m\n' $todo
fi
