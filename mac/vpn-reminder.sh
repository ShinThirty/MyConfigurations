#!/bin/zsh
#
# vpn-reminder.sh — VPN reminder (SECURITY.md section 9). When the Mac is on a
# network you haven't trusted and its traffic isn't in a tunnel, shows a
# dialog: on joining such a network, and again each time the VPN drops. A
# dialog rather than a notification, since Focus hides those.
#
#   mac/vpn-reminder.sh --register    install the launch agent (bootstrap.sh does this)
#   mac/vpn-reminder.sh --trust       trust the network the Mac is on now
#
# The agent runs it at login and whenever the network changes. A network is
# known by its router's hardware address, since macOS hides the Wi-Fi name from
# a script without Location Services. The trusted ones are listed one per line
# in ~/.config/vpn-reminder/trusted, not in this repo, which is public: a
# router's address can be looked up to where it is.

label=local.vpn-reminder
trusted=$HOME/.config/vpn-reminder/trusted
state=~/.local/state/vpn-reminder

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
    <key>LaunchEvents</key>
    <dict>
        <key>com.apple.notifyd.matching</key>
        <dict>
            <key>network-change</key>
            <dict>
                <key>Notification</key>
                <string>com.apple.system.config.network_change</string>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
EOF
  launchctl bootout gui/$UID/$label 2>/dev/null
  launchctl bootstrap gui/$UID $plist || exit
  print "Registered launch agent: $label (at login and on every network change)"
  exit
fi

# The hardware address of the router of each network the Mac is on, one per
# line: the routers its interfaces got over DHCP
routers() {
  local dev ip
  for dev in $(networksetup -listallhardwareports | awk '/^Device:/ { print $2 }'); do
    ip=$(ipconfig getoption $dev router 2>/dev/null)
    [[ -n $ip ]] || continue
    # A router just joined may not be in the ARP cache yet
    ping -c 1 -t 1 $ip >/dev/null 2>&1
    arp -n $ip | awk '$4 ~ /:/ { print $4 }'
  done | sort -u
}

now=$(routers)

if [[ $1 == --trust ]]; then
  [[ -n $now ]] || { print "The Mac isn't on a network with a router"; exit 1 }
  mkdir -p ${trusted:h}
  { print -r -- $now; cat $trusted 2>/dev/null } | sort -u >$trusted.new && mv $trusted.new $trusted
  print "Trusted this network; $(wc -l <$trusted | tr -d ' ') in $trusted"
  exit
fi

# Whether traffic to an address on the internet goes through a tunnel
# interface, or nowhere: utun for most VPNs (WireGuard, OpenVPN, Proton VPN,
# Clash Verge Rev's TUN mode), ipsec for IKEv2, ppp for L2TP. An address rather
# than the default route, since some VPNs replace that and others leave it and
# cover the internet with narrower routes.
tunneled() {
  local via=$(route -n get "$@" 2>/dev/null | awk '/interface:/ { print $2 }')
  [[ -z $via || $via == (utun|ipsec|ppp)* ]]
}

# On a network you haven't trusted, with IPv4 or IPv6 traffic outside a tunnel.
# A VPN that carries only IPv4 leaves IPv6 on the network, where it has IPv6.
exposed() {
  [[ -n $now ]] && print -r -- $now | grep -qvxFf <(cat $trusted 2>/dev/null) &&
    ! { tunneled 1.1.1.1 && tunneled -inet6 2606:4700:4700::1111 }
}

# Once each time the Mac becomes exposed. An event while it stays so, like
# another from the same network, changes nothing.
if ! exposed; then
  command rm -f $state/reminded
  exit 0
fi
[[ $now == "$(cat $state/reminded 2>/dev/null)" ]] && exit 0
# A VPN reconnecting after sleep, or changing servers, is back by then
sleep 10
now=$(routers)
exposed || exit 0
mkdir -p $state
print -r -- $now >$state/reminded

# With macOS's open padlock, or its caution sign if a release drops that
icon=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/UnlockedIcon.icns
[[ -f $icon ]] && icon="POSIX file \"$icon\"" || icon=caution
osascript -e "display dialog \"A network you haven't trusted\" & return & return & \"Its traffic isn't going through a VPN. Connect one once past the network's sign-in page. If the network is yours: mac/vpn-reminder.sh --trust (SECURITY.md section 9)\" with title \"VPN reminder\" buttons {\"OK\"} default button 1 with icon $icon" >/dev/null
