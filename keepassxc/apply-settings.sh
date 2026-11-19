#!/usr/bin/env bash
#
# Merges keepassxc.ini into KeePassXC's own settings file, and
# keepassxc_local.ini into the one it keeps for settings that stay on the
# machine, and on macOS has it start at login: the counterpart of
# apply-settings.ps1. It sets this machine's BackupFilePathPattern too, where
# KeePassXC copies a database before saving it: ~/.local/share/keepassxc/backup,
# which it makes the owner's alone when it isn't there yet. KeePassXC rewrites
# its files when it saves its settings and when it quits, so quit it first;
# with MinimizeOnClose, closing its window only hides it. Keys the two don't
# name are left alone, KeeShare's private key and whether Arch's Secret Service
# is on among them, so rerunning is harmless. Each previous file is kept beside
# it, with .bak added; with no file yet, KeePassXC starts from these settings.
#
# Starting at login, minimized to the tray by MinimizeOnStartup:
#   macOS  a launch agent, local.keepassxc, which this writes and loads. It
#          runs start.sh, which opens tp-share's database at home, once
#          mac/vpn-reminder.sh has mounted the share, and the local copy
#          anywhere else. Leave KeePassXC's own
#          Settings → General → Automatically launch KeePassXC at system
#          startup off
#   Arch   start.arch.sh, which waits for waybar's tray; Hyprland's
#          UserConfigs/user_startup.lua runs it (MIGRATION.arch.md
#          section 2); arch/kooldots-upgrade.sh puts that line back when
#          KooL's upgrade drops or changes it, and arch/steps/80-settings.zsh
#          checks it, so this leaves it alone
#
# --check writes nothing; it lists what differs instead. The platform's
# steps/80-settings.zsh runs it.
#
set -euo pipefail

# Bash expands a bare ~ in ${path/#$HOME/~} back to $HOME, so the paths this
# prints take their ~ from a variable
tilde='~'

here="$(cd "$(dirname "$0")" && pwd)"
label=local.keepassxc
plist="$HOME/Library/LaunchAgents/$label.plist"

case "$OSTYPE" in
  darwin*)
    ini="$HOME/Library/Application Support/KeePassXC/keepassxc.ini"
    local_ini="$HOME/Library/Caches/KeePassXC/keepassxc.ini"
    process=KeePassXC
    ;;
  linux*)
    ini="${XDG_CONFIG_HOME:-$HOME/.config}/keepassxc/keepassxc.ini"
    local_ini="${XDG_STATE_HOME:-$HOME/.local/state}/keepassxc/keepassxc.ini"
    process=keepassxc
    ;;
  *)
    echo "No KeePassXC settings location for $OSTYPE yet" >&2
    exit 1
    ;;
esac
# keepassxc.ini's BackupBeforeSave copies the database here before each save.
# KeePassXC expands {DB_FILENAME}, but not ~ or $HOME
backup="$HOME/.local/share/keepassxc/backup/{DB_FILENAME}.old.kdbx"

# KeePassXC's two files, what each is, and the repo's settings for it, with
# this machine's own after them
files=("$ini" "$local_ini")
names=("settings file" "local settings file")
from=(keepassxc.ini keepassxc_local.ini)
own=("$(printf '[General]\nBackupFilePathPattern=%s' "$backup")" "")

# Reads the repo's settings, then KeePassXC's file, with this machine's own
# settings in $machine_settings. mode=merge prints KeePassXC's file with those
# values in place of its own, and the keys it lacks at the end of their
# section; mode=check prints each setting that differs, and where its value is
# from.
merge='
function now(v) { return v == "" ? "empty" : v }
function wanted(v) { return v == "" ? "it empty" : v }
function emit(line) { if (mode == "merge") print line; printed++ }
function missing(   n, mk) {
  for (n = 1; n <= nkeys[s]; n++) {
    mk = key[s, n]
    if (!((s, mk) in have)) emit(mk "=" want[s, mk])
  }
}
# A line of the settings, by section, in order, and where its value is from
function setting(line, source,   i, k) {
  sub(/\r$/, "", line)
  if (line ~ /^[ \t]*[#;]/ || line !~ /[^ \t]/) return
  if (line ~ /^\[.*\]$/) {
    r = line
    if (!(r in nkeys)) { order[++nsec] = r; nkeys[r] = 0 }
    return
  }
  i = index(line, "=")
  k = substr(line, 1, i - 1)
  if (!((r, k) in want)) key[r, ++nkeys[r]] = k
  want[r, k] = substr(line, i + 1)
  from[r, k] = source
}
function machine(   n, j, lines) {
  added = 1
  n = split(ENVIRON["machine_settings"], lines, "\n")
  for (j = 1; j <= n; j++) setting(lines[j], "apply-settings.sh sets")
}
# The repo file
FNR == NR {
  if (FNR == 1) { repo = FILENAME; sub(/.*\//, "", repo) }
  setting($0, repo " has")
  next
}
# Then the file KeePassXC writes, line by line, once the settings for this
# machine are in. Blank lines wait, so the keys a section lacks go before the
# blank line that ends it
!added { machine() }
{ sub(/\r$/, "") }
!/./ { blanks++; next }
/^\[.*\]$/ { missing(); s = $0; seen[s] = 1 }
!/^\[/ {
  i = index($0, "=")
  if (i) {
    k = substr($0, 1, i - 1)
    if ((s, k) in want) { have[s, k] = substr($0, i + 1); $0 = k "=" want[s, k] }
  }
}
{ for (; blanks; blanks--) emit(""); emit($0) }
END {
  if (!added) machine()
  missing()
  for (j = 1; j <= nsec; j++) {
    if (order[j] in seen) continue
    if (printed) emit("")
    s = order[j]
    emit(s)
    missing()
  }
  if (mode != "check") exit
  for (j = 1; j <= nsec; j++) {
    s = order[j]
    for (m = 1; m <= nkeys[s]; m++) {
      k = key[s, m]
      name = substr(s, 2, length(s) - 2) "/" k
      if (!((s, k) in have)) print name " is unset, " from[s, k] " " wanted(want[s, k])
      else if (have[s, k] != want[s, k]) print name " is " now(have[s, k]) ", " from[s, k] " " wanted(want[s, k])
    }
  }
}'

agent() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$here/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
}
loaded() { launchctl print "gui/$UID/$label" >/dev/null 2>&1; }

# compare <n> <mode>: KeePassXC's file n with the settings for it, as $merge has
compare() {
  local file=${files[$1]}
  [[ -f $file ]] || file=/dev/null
  machine_settings=${own[$1]} awk -v mode="$2" "$merge" "$here/${from[$1]}" "$file"
}

if [[ ${1-} == --check ]]; then
  for n in 0 1; do
    if [[ -f ${files[n]} ]]; then
      compare $n check
    else
      echo "${names[n]}, ${files[n]/#$HOME/$tilde}, isn't there yet"
    fi
  done
  if [[ $OSTYPE == darwin* ]]; then
    # Login loads the file, so a stale one counts even with the job loaded
    if [[ ! -f $plist ]]; then
      echo "launch agent, $label, isn't there, so it doesn't start at login"
    elif [[ "$(cat "$plist")" != "$(agent)" ]]; then
      echo "launch agent, $label, isn't the one apply-settings.sh writes, so login may not run start.sh"
    elif ! loaded; then
      echo "launch agent, $label, isn't loaded, so it doesn't start at login"
    fi
  fi
  exit 0
fi

changes=("$(compare 0 check)" "$(compare 1 check)")
if [[ -z ${changes[0]}${changes[1]} ]]; then
  echo "KeePassXC's settings are already keepassxc.ini's and keepassxc_local.ini's"
elif pgrep -x "$process" >/dev/null; then
  echo "KeePassXC is running and would write its own settings back when it quits; quit it first (closing its window only hides it)" >&2
  exit 1
else
  # KeePassXC makes a missing folder readable by anyone; this one is the owner's
  (umask 077 && mkdir -p "$(dirname "$backup")")
  for n in 0 1; do
    [[ -n ${changes[n]} ]] || continue
    file=${files[n]}
    mkdir -p "$(dirname "$file")"
    if [[ -f $file ]]; then cp -p "$file" "$file.bak"; fi
    tmp="$(mktemp "$file.XXXXXX")"
    compare $n merge >"$tmp"
    mv "$tmp" "$file"
    echo "Merged ${from[n]} into ${file/#$HOME/$tilde}: $(printf '%s\n' "${changes[n]}" | wc -l | tr -d ' ') settings changed"
  done
fi

if [[ $OSTYPE == darwin* ]]; then
  # Loading it runs it, so KeePassXC starts now too
  if [[ "$(cat "$plist" 2>/dev/null)" != "$(agent)" ]]; then
    mkdir -p "$(dirname "$plist")"
    agent >"$plist"
    launchctl bootout "gui/$UID/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$UID" "$plist"
    echo "Registered launch agent $label, which opens KeePassXC at login"
  elif ! loaded; then
    launchctl bootstrap "gui/$UID" "$plist"
    echo "Loaded launch agent $label, which opens KeePassXC at login"
  else
    echo "Launch agent $label already opens KeePassXC at login"
  fi
fi
