#!/usr/bin/env bash
#
# Brings up KeePassXC's window on Arch, for Hyprland's SUPER+ALT+K in
# UserConfigs/user_keybinds.lua, which arch/kooldots-upgrade.sh puts back when
# KooL's upgrade drops it. An open window gets the focus, on whichever
# workspace it is; from the tray, the window opens on this workspace; and when
# KeePassXC isn't running, start.arch.sh starts it, as at login, and the window
# opens once it's up.
#
# KeePassXC runs once per user: a second keepassxc has the first show its
# window, and quits. Hyprland doesn't focus a window an app shows by itself,
# so this does.
#

class=org.keepassxc.KeePassXC
# Where KeePassXC keeps its single-instance lock, which names its PID
lock="${TMPDIR:-/tmp}/keepassxc-$USER.lock"

window() {
  hyprctl clients -j | jq -r --arg class "$class" 'first(.[] | select(.class == $class) | .address) // empty'
}

# Focuses the window once it's there, waiting up to 5 seconds
focus() {
  local addr
  for _ in {1..50}; do
    addr="$(window)"
    [[ -n $addr ]] && exec hyprctl dispatch "hl.dsp.focus({ window = 'address:$addr' })" >/dev/null
    sleep 0.1
  done
  exit 1
}

[[ -n "$(window)" ]] && focus

if ! pgrep -u "$UID" -x keepassxc >/dev/null; then
  "${BASH_SOURCE[0]%/*}/start.arch.sh" >/dev/null 2>&1 &
  pid=$!
  # start.arch.sh execs keepassxc, so it's up once the lock names this PID. A
  # second keepassxc before that would start another KeePassXC
  until [[ "$(head -n 1 "$lock" 2>/dev/null)" == "$pid" ]]; do
    kill -0 "$pid" 2>/dev/null || exit 1
    sleep 0.1
  done
fi
keepassxc >/dev/null 2>&1
focus
