#!/usr/bin/env bash
#
# Starts Helium on Arch once KeePassXC's Login database is unlocked. Helium
# reads the key its cookies are encrypted with from the Secret Service, so from
# Login, when it starts (helium-browser-flags.conf). Started without the key,
# it deletes every cookie it can't decrypt, which signs you out of every site.
# So this asks KeePassXC to unlock Login and waits, for up to 5 minutes. If
# Login stays locked, or KeePassXC isn't running, Helium doesn't start and a
# notification says why. A Helium that's already running has its key, so a link
# or a new window goes straight to it.
#
# Helium's menu entry runs this, and so do Super+B and links from other apps,
# which open the default browser through it. --install writes that entry,
# ~/.local/share/applications/helium.desktop: Helium's own, with each Exec
# running this script. Rerun it when an update changes Helium's entry. --check
# writes nothing; it lists what differs instead, and arch/steps/80-settings.zsh
# runs it. macOS and Windows keep Helium's key in the login Keychain and DPAPI,
# which the login unlocks, so they have no counterpart.
#
set -uo pipefail

# -P, so the entry's Exec is the same however the script was reached
here="$(cd "$(dirname "$0")" && pwd -P)"
own=/usr/share/applications/helium.desktop
entry="${XDG_DATA_HOME:-$HOME/.local/share}/applications/helium.desktop"

desktop_entry() {
  echo "# helium/start.arch.sh --install wrote this from $own"
  sed -E "s#^Exec=helium-browser( |\$)#Exec=$here/start.arch.sh\\1#" "$own"
}

case ${1-} in
  --install)
    [[ -f $own ]] || { echo "Helium isn't installed: there's no $own" >&2; exit 1; }
    mkdir -p "$(dirname "$entry")"
    desktop_entry >"$entry"
    echo "Wrote ${entry/#$HOME/\~}"
    exit 0
    ;;
  --check)
    [[ -f $own ]] || exit 0
    if [[ ! -f $entry ]]; then
      echo "menu entry, ${entry/#$HOME/\~}, isn't there, so Helium can start while KeePassXC's Login database is locked, and delete its cookies"
    elif ! cmp -s "$entry" <(desktop_entry); then
      echo "menu entry, ${entry/#$HOME/\~}, isn't Helium's own with each Exec running helium/start.arch.sh"
    fi
    exit 0
    ;;
esac

pgrep -u "$UID" -x helium >/dev/null && exec helium-browser "$@"

refuse() {
  notify-send -a Helium -i helium-browser "Helium didn't start" "$1"
  exit 1
}

# One launch at a time asks for the unlock, and the others wait for it. Helium
# doesn't inherit the lock, or the next launch would wait for it to quit
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/helium-start.lock"
flock 9

# Exits 0 once Login is unlocked, 1 if it stays locked, and 2 if KeePassXC
# doesn't have it open. The Secret Service lists every database KeePassXC has
# open while it's locked, the main one too, since KeePassXC can't read a locked
# database's Secret Service settings (SECURITY.md section 7). So this unlocks
# Login's alone, by its collection, which KeePassXC names after the file
# keepassxc/start.arch.sh opens, ~/.local/share/keepassxc/login.kdbx. KeePassXC
# looks for Helium's key only in unlocked databases, so the main one can stay
# locked. KeePassXC finishes an unlock only for the connection that asked for
# it, while it's still open, so one connection asks, then waits for you to
# unlock Login or cancel
python3 -I - /org/freedesktop/secrets/collection/login 2>/dev/null <<'EOF'
import sys
from gi.repository import Gio, GLib

name, root, secret = 'org.freedesktop.secrets', '/org/freedesktop/secrets', 'org.freedesktop.Secret.'
login = sys.argv[1]

def call(path, iface, method, args, reply=None):
    return bus.call_sync(name, path, iface, method, args, reply and GLib.VariantType(reply),
                         Gio.DBusCallFlags.NONE, -1, None)

def get(path, iface, prop):
    return call(path, 'org.freedesktop.DBus.Properties', 'Get',
                GLib.Variant('(ss)', (secret + iface, prop)), '(v)').unpack()[0]

try:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    collections = get(root, 'Service', 'Collections')
except GLib.Error:
    sys.exit(2)
if login not in collections:
    sys.exit(2)
if get(login, 'Collection', 'Locked'):
    _, prompt = call(root, secret + 'Service', 'Unlock', GLib.Variant('(ao)', ([login],)), '(aoo)').unpack()
    if prompt != '/':
        loop = GLib.MainLoop()
        bus.signal_subscribe(name, secret + 'Prompt', 'Completed', prompt, None,
                             Gio.DBusSignalFlags.NONE, lambda *_: loop.quit())
        GLib.timeout_add_seconds(300, loop.quit)
        call(prompt, secret + 'Prompt', 'Prompt', GLib.Variant('(s)', ('',)))
        loop.run()
sys.exit(1 if get(login, 'Collection', 'Locked') else 0)
EOF
case $? in
  0) ;;
  2) refuse "KeePassXC isn't running, or Login isn't open in it, so Helium would find no key for its cookies and delete them" ;;
  *) refuse "KeePassXC's Login database is locked, so Helium would find no key for its cookies and delete them. Unlock Login, then start Helium again" ;;
esac

exec 9>&-
exec helium-browser "$@"
