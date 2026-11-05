#!/usr/bin/env bash
#
# Starts KeePassXC at login on macOS with the database for where the Mac is:
# tp-share's at home, once mac/vpn-reminder.sh's agent has mounted the share,
# and the local copy, which is read-only, anywhere else. The launch agent
# apply-settings.sh writes, local.keepassxc, runs this. Home is the network
# vpn-reminder.sh --home marked, the only one it mounts the share on
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
  /bin/zsh "$here/../mac/vpn-reminder.sh" --at-home
  home=$?
  [[ $home == 2 ]] || break
  sleep 1
done

db=$backup
if [[ $home == 0 ]]; then
  # vpn-reminder.sh mounts the share once its SMB port answers, so it's waited
  # for only then
  if nc -z -G 3 tp-share 445 2>/dev/null; then
    for _ in {1..30}; do
      [[ -f $remote ]] && break
      sleep 1
    done
  fi
  [[ -f $remote ]] && db=$remote
fi

# -g leaves KeePassXC in the background. Already running, it gets nothing
open -g -a KeePassXC --args "$db"
