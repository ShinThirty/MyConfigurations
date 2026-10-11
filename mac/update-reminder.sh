#!/bin/zsh
#
# update-reminder.sh — monthly update reminder (MIGRATION.md section 8). From
# the day after Patch Tuesday until update.sh records a run, posts a
# notification at most once a day.
#
#   mac/update-reminder.sh --register    install the launch agent (bootstrap.sh does this)
#
# The agent runs it at login and daily at noon; launchd runs a noon missed
# while the Mac slept as soon as it wakes. The schedule is
# powershell/update_reminder.ps1's, so the Mac comes due with the Windows box.

label=local.monthly-update-reminder

if [[ $1 == --register ]]; then
  plist=~/Library/LaunchAgents/$label.plist
  mkdir -p ${plist:h}
  cat >$plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>${0:A}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>12</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF
  launchctl bootout gui/$UID/$label 2>/dev/null
  launchctl bootstrap gui/$UID $plist || exit
  print "Registered launch agent: $label (at login and daily at noon)"
  exit
fi

state=~/.local/state/monthly-update

# Cumulative updates ship on Patch Tuesday, the second Tuesday (the 8th-14th).
# Prints the day after it for the month given as YYYY-MM.
due_date() {
  local weekday=$(date -j -f %Y-%m-%d "$1-08" +%u)     # 1 is Monday
  printf '%s-%02d\n' $1 $(( 8 + (9 - weekday) % 7 + 1 ))
}
today=$(date +%Y-%m-%d)
due=$(due_date ${today%-*})
[[ $today < $due ]] && due=$(due_date $(date -j -v-1m -f %Y-%m-%d "${today%-*}-01" +%Y-%m))

stamp() { cat "$state/$1" 2>/dev/null }
[[ $(stamp last-run) < $due && $(stamp last-reminder) < $today ]] || exit 0

osascript -e 'display notification "Run mac/update.sh from MyConfigurations, then install what Software Update has" with title "Monthly update" subtitle "MIGRATION.md section 8"'

mkdir -p $state
print $today >$state/last-reminder
