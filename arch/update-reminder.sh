#!/usr/bin/env bash
#
# Monthly update reminder (MIGRATION.arch.md section 10). From the day after
# Patch Tuesday until update.sh records a run, shows a notification at most once
# a day. Arch has no release day of its own; sharing the Windows reminder's due
# date puts both systems into the same monthly sitting.
# Run by update-reminder.timer, from the symlinks.linux links.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/monthly-update"

# Windows' cumulative update ships on Patch Tuesday, the second Tuesday (the 8th-14th)
due_date() {
  local first
  first="$(date -d "$1" +%Y-%m-01)"
  date -d "$first +$(( (9 - $(date -d "$first" +%u)) % 7 + 8 )) days" +%F
}
today="$(date +%F)"
due="$(due_date "$today")"
[[ $today < $due ]] && due="$(due_date "$(date -d "${today:0:7}-01 -1 day" +%F)")"

stamp() { cat "$STATE_DIR/$1" 2>/dev/null || echo 0000-00-00; }
[[ $(stamp last-run) < $due && $(stamp last-reminder) < $today ]] || exit 0

# A tty login has nowhere to show it; the next graphical login will
[[ -n ${WAYLAND_DISPLAY:-} ]] || exit 0

mkdir -p "$STATE_DIR"
echo "$today" > "$STATE_DIR/last-reminder"
# Critical, so swaync keeps it on screen until it's dismissed. --wait blocks
# until then, for the button's answer
action="$(notify-send --wait --urgency=critical --app-name='Monthly update' \
  --icon=system-software-update --action=run='Update now' \
  'Monthly update' $'Run arch/update.sh from MyConfigurations\nMIGRATION.arch.md section 10')" ||
  { rm -f "$STATE_DIR/last-reminder"; exit 1; }   # no notification daemon yet: try again next time

# exec: systemd stops the unit, killing everything in it, once this process
# exits, so the terminal has to become this process
[[ $action == run ]] && exec kitty --hold --title 'Monthly update' "$DOTFILES/arch/update.sh"
exit 0
