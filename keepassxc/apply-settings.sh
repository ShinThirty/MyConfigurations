#!/usr/bin/env bash
#
# Merges keepassxc.ini into KeePassXC's own settings file, and on macOS has it
# start at login: the counterpart of apply-settings.ps1. KeePassXC rewrites its
# file when it saves its settings and when it quits, so quit it first; with
# MinimizeOnClose, closing its window only hides it. Keys keepassxc.ini doesn't
# name are left alone, KeeShare's private key and Arch's Secret Service among
# them, so rerunning is harmless. The previous file is kept as
# keepassxc.ini.bak; with no file yet, KeePassXC starts from keepassxc.ini's.
#
# Starting at login, minimized to the tray by MinimizeOnStartup:
#   macOS  a launch agent, local.keepassxc, which this writes and loads, and
#          which opens KeePassXC as the Dock would. Leave KeePassXC's own
#          Settings → General → Automatically launch KeePassXC at system
#          startup off
#   Arch   Hyprland's UserConfigs/user_startup.lua, which starts it with the
#          Login database once waybar's tray is up (MIGRATION.arch.md
#          section 2); arch/kooldots-upgrade.sh puts that line back when KooL's
#          upgrade drops it, so this leaves it alone
#
# --check writes nothing; it lists what differs instead. The platform's
# steps/80-settings.zsh runs it.
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
label=local.keepassxc
plist="$HOME/Library/LaunchAgents/$label.plist"

case "$OSTYPE" in
  darwin*)
    ini="$HOME/Library/Application Support/KeePassXC/keepassxc.ini"
    process=KeePassXC
    ;;
  linux*)
    ini="${XDG_CONFIG_HOME:-$HOME/.config}/keepassxc/keepassxc.ini"
    process=keepassxc
    ;;
  *)
    echo "No KeePassXC settings location for $OSTYPE yet" >&2
    exit 1
    ;;
esac
current="$ini"
[[ -f $ini ]] || current=/dev/null

# Reads keepassxc.ini, then KeePassXC's file. mode=merge prints KeePassXC's
# file with keepassxc.ini's values in place of its own, and the keys it lacks at
# the end of their section; mode=check prints each setting that differs.
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
# keepassxc.ini: its settings, by section, in order
FNR == NR {
  sub(/\r$/, "")
  if ($0 ~ /^[ \t]*[#;]/ || $0 !~ /[^ \t]/) next
  if ($0 ~ /^\[.*\]$/) {
    r = $0
    if (!(r in nkeys)) { order[++nsec] = r; nkeys[r] = 0 }
    next
  }
  i = index($0, "=")
  k = substr($0, 1, i - 1)
  if (!((r, k) in want)) key[r, ++nkeys[r]] = k
  want[r, k] = substr($0, i + 1)
  next
}
# Then the file KeePassXC writes, line by line. Blank lines wait, so the keys
# a section lacks go before the blank line that ends it
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
      if (!((s, k) in have)) print name " is unset, keepassxc.ini has " wanted(want[s, k])
      else if (have[s, k] != want[s, k]) print name " is " now(have[s, k]) ", keepassxc.ini has " wanted(want[s, k])
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
        <string>/usr/bin/open</string>
        <string>-a</string>
        <string>KeePassXC</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
}
loaded() { launchctl print "gui/$UID/$label" >/dev/null 2>&1; }

if [[ ${1-} == --check ]]; then
  if [[ -f $ini ]]; then
    awk -v mode=check "$merge" "$here/keepassxc.ini" "$ini"
  else
    echo "settings file, ${ini/#$HOME/~}, isn't there yet"
  fi
  if [[ $OSTYPE == darwin* ]] && ! loaded; then
    echo "launch agent, $label, isn't loaded, so it doesn't start at login"
  fi
  exit 0
fi

changes="$(awk -v mode=check "$merge" "$here/keepassxc.ini" "$current")"
if [[ -z $changes ]]; then
  echo "KeePassXC's settings are already keepassxc.ini's"
elif pgrep -x "$process" >/dev/null; then
  echo "KeePassXC is running and would write its own settings back when it quits; quit it first (closing its window only hides it)" >&2
  exit 1
else
  mkdir -p "$(dirname "$ini")"
  if [[ -f $ini ]]; then cp -p "$ini" "$ini.bak"; fi
  tmp="$(mktemp "$ini.XXXXXX")"
  awk -v mode=merge "$merge" "$here/keepassxc.ini" "$current" >"$tmp"
  mv "$tmp" "$ini"
  echo "Merged keepassxc.ini into ${ini/#$HOME/~}: $(printf '%s\n' "$changes" | wc -l | tr -d ' ') settings changed"
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
