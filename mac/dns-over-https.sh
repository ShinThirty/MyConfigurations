#!/usr/bin/env bash
#
# Builds a configuration profile that sends every DNS lookup to Cloudflare over
# HTTPS, whatever server the network hands out, and opens it (SECURITY.md
# section 9). macOS has no setting for encrypted DNS, only profiles and apps.
# Opening the file only stages it: install it in System Settings → General →
# Device Management. Run this again after changing it; the new profile replaces
# the old one, since its identifier stays the same.
#
# Without AllowFailover, a lookup Cloudflare can't answer fails rather than
# going out in plain text: where it's blocked, set Cloudflare to Disabled in
# System Settings → Network → VPN & Filters until you leave. While a VPN is on,
# macOS asks the VPN's DNS server instead, and its window for a network's
# sign-in page asks the network's own, for the names that page needs.
#
# --check writes nothing; it lists what differs between this and the installed
# profile instead, and whether its switch is off. mac/steps/80-settings.zsh
# runs it.
#
set -euo pipefail

id=local.dns-over-https
# The addresses spare macOS a plain lookup of cloudflare-dns.com to begin with
settings='{
  "DNSProtocol": "HTTPS",
  "ServerURL": "https://cloudflare-dns.com/dns-query",
  "ServerAddresses": ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"]
}'
switch='Cloudflare in System Settings → Network → VPN & Filters'

if [[ ${1-} == --check ]]; then
  # system_profiler lists the installed profiles without sudo, each payload's
  # settings as an old-style plist, which plutil reads
  installed="$(system_profiler -json SPConfigurationProfileDataType |
    jq -r --arg id "$id.cloudflare" '.. | objects
      | select(.spconfigprofile_payload_identifier? == $id) | .spconfigprofile_payload_data')"
  if [[ -z $installed ]]; then
    echo "isn't installed: run mac/dns-over-https.sh"
    exit 0
  fi
  # Each setting as 'name = value', the addresses in any order
  leaves='.ServerAddresses |= sort? | to_entries[] | "\(.key) = \(.value | if type == "array" then join(" ") else . end)"'
  comm -3 <(jq -r "$leaves" <<<"$settings" | sort) \
    <(plutil -convert json -o - - <<<"$installed" | jq -r ".DNSSettings | $leaves" | sort) |
    awk -F'\t' '$1 != "" { print "has no " $1 ": run mac/dns-over-https.sh again"; next }
      { print "has " $2 ", which mac/dns-over-https.sh doesn\047t: run it again" }'
  # The switch is kept with the VPNs' settings, in an archive of objects that
  # plutil can't turn into JSON: find the configuration this profile made, by
  # its identifier, and read only its DNS settings' Enabled
  enabled="$(/usr/bin/python3 -I - "$id" 2>/dev/null <<'EOF' || true
import plistlib, sys
objs = plistlib.load(open('/Library/Preferences/com.apple.networkextension.plist', 'rb'))['$objects']
def get(o, key):
    v = o.get(key) if isinstance(o, dict) else None
    return objs[v.data] if isinstance(v, plistlib.UID) else v
for o in objs:
    if get(get(o, 'ProfileInfo'), 'ProfileIdentifier') == sys.argv[1]:
        print(get(get(o, 'DNSSettings'), 'Enabled'))
EOF
)"
  case $enabled in
    True) ;;
    False) echo "is off: set $switch to Enabled" ;;
    *) echo "has a switch this script can't read: check that $switch is Enabled" ;;
  esac
  exit 0
fi

out="$(mktemp -d)/DNS over HTTPS.mobileconfig"
jq --arg id "$id" '{
  PayloadType: "Configuration",
  PayloadVersion: 1,
  PayloadIdentifier: $id,
  PayloadUUID: "76FE8E64-4E1F-4B28-A7CD-C0116DF2861D",
  PayloadDisplayName: "DNS over HTTPS",
  PayloadDescription: "Cloudflare, from mac/dns-over-https.sh in MyConfigurations",
  PayloadScope: "System",
  PayloadContent: [{
    PayloadType: "com.apple.dnsSettings.managed",
    PayloadVersion: 1,
    PayloadIdentifier: "\($id).cloudflare",
    PayloadUUID: "FEF82EEC-EC00-48F0-A1FF-4B74B16EA736",
    PayloadDisplayName: "Cloudflare",
    DNSSettings: .
  }]
}' <<<"$settings" | plutil -convert xml1 -o "$out" -
plutil -lint "$out" >/dev/null
open "$out"
open 'x-apple.systempreferences:com.apple.Profiles-Settings.extension'
echo "Opened ${out/#$HOME/~}: install it in System Settings → General → Device Management"
