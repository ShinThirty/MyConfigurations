#!/usr/bin/env bash
#
# Starts KeePassXC at login on macOS with the database for where the Mac is:
# tp-share's at home, mounting the share if it isn't, and the local copy,
# which is read-only, anywhere else. The launch agent apply-settings.sh writes,
# local.keepassxc, runs this. Home is a network mac/vpn-reminder.sh trusts: on
# any other, whoever answers for the share's name gets the login attempt
# (SECURITY.md section 9). KeePassXC starts in the menu bar with the database
# locked, as MinimizeOnStartup has it.
#
# It leaves the local copy as it is: macOS won't let a script launchd starts
# read files on a network volume, only see that they're there, so sync.sh
# fails here. Run sync.sh by hand; the monthly update lists a copy that's
# behind the share's.
#

here="$(cd "$(dirname "$0")" && pwd)"
# The share's database, and sync.sh's local copy of it
remote=/Volumes/tp-share/Password/shinthirty.kdbx
backup="$HOME/.local/share/keepass/shinthirty.kdbx"

# The Wi-Fi can still be joining at login: 2 is no network yet
for _ in {1..30}; do
  /bin/zsh "$here/../mac/vpn-reminder.sh" --trusted
  trusted=$?
  [[ $trusted == 2 ]] || break
  sleep 1
done

db=$backup
if [[ $trusted == 0 ]]; then
  # Only when the share's SMB port answers: mount volume waits minutes for a
  # server that doesn't, as from the phone's hotspot. It mounts with the login
  # Finder keeps in the Keychain
  if [[ ! -f $remote ]] && nc -z -G 3 tp-share 445 2>/dev/null; then
    osascript -e 'mount volume "smb://tp-share/G"' >/dev/null 2>&1
  fi
  [[ -f $remote ]] && db=$remote
fi

# -g leaves KeePassXC in the background. Already running, it gets nothing
open -g -a KeePassXC --args "$db"
