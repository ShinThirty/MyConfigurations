#!/usr/bin/env bash
#
# Refreshes the Mac's local copy of the password database from tp-share's
# (macOS). The share's is the one in use, the one KeePassXC opens at home
# (start.sh) and every machine saves to. The local copy is what start.sh opens
# away from home, so it stays read-only: an entry saved there would never reach
# the share. Mode 444 alone doesn't stop KeePassXC, which saves by replacing
# the file, a change to the folder rather than the file; macOS's user
# immutable flag does, and you can lift it without sudo (chflags nouchg).
# start.sh runs this at each login at home, so run it by hand when the Mac has
# been logged in for a while and you're about to leave. It only copies, so it
# needs no password.
#
# --check writes nothing; it lists a local copy that's missing, writable, or
# behind the share's while that's mounted. mac/steps/80-settings.zsh runs it.
#
set -euo pipefail

backup="$HOME/.local/share/keepass/shinthirty.kdbx"
remote=/Volumes/tp-share/Password/shinthirty.kdbx

# Read-only both ways: no write permission, and the immutable flag
locked() { [[ ! -w $backup && "$(stat -f %Sf "$backup")" == *uchg* ]]; }

if [[ ${1-} == --check ]]; then
  if [[ ! -f $backup ]]; then
    echo "local copy of the database, ${backup/#$HOME/~}, isn't there"
    exit 0
  fi
  locked || echo "local copy of the database, ${backup/#$HOME/~}, isn't read-only"
  if [[ -f $remote ]] && ! cmp -s "$remote" "$backup"; then
    echo "local copy of the database is behind tp-share's"
  fi
  exit 0
fi

[[ -f $remote ]] || { echo "tp-share isn't mounted: connect to it at home, then run this again" >&2; exit 1; }
# Every KeePass 2 database starts with these 8 bytes. Anything else would
# replace a copy that works
if [[ "$(od -An -tx1 -N8 "$remote" | tr -d ' \n')" != 03d9a29a67fb4bb5 ]]; then
  echo "$remote isn't a KeePass database, so the local copy stays as it is" >&2
  exit 1
fi

mkdir -p "$(dirname "$backup")"
if [[ -f $backup ]] && cmp -s "$remote" "$backup"; then
  echo "The local copy is already tp-share's"
else
  tmp="$(mktemp "$backup.XXXXXX")"
  cp "$remote" "$tmp"
  cmp -s "$remote" "$tmp" || { command rm -f "$tmp"; echo "The copy doesn't match tp-share's; the local copy stays as it is" >&2; exit 1; }
  [[ -e $backup ]] && chflags nouchg "$backup"
  mv -f "$tmp" "$backup"
  echo "Copied tp-share's database to ${backup/#$HOME/~}"
fi
chflags nouchg "$backup"
chmod 444 "$backup"
chflags uchg "$backup"
