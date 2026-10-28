#!/usr/bin/env bash
#
# Builds a configuration profile from policies.json and opens it, which is how
# Helium gets its policies on macOS (MIGRATION.md section 3). Helium reads them
# from its preferences domain, net.imput.helium, but a mandatory-only policy
# like ExtensionInstallForcelist counts only when the value is forced, and a
# profile is what forces it; `defaults write` doesn't. Opening the file only
# stages it: install it in System Settings → General → Device Management. Run
# this again after changing policies.json; the new profile replaces the old
# one, since its identifier stays the same.
#
# --check writes nothing; it lists what differs between policies.json and the
# installed policies instead. mac/steps/80-settings.zsh runs it.
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
domain=net.imput.helium
installed="/Library/Managed Preferences/$domain.plist"

if [[ ${1-} == --check ]]; then
  # Each value as 'name = value' or 'name[i] = value', the file's against the
  # installed ones. macOS adds PayloadUUID and _manualProfile to the latter.
  leaves='with_entries(select(.key | test("^(Payload|_)") | not))
    | paths(type != "object" and type != "array") as $p
    | "\($p | map(if type == "number" then "[\(.)]" else . end) | join("")) = \(getpath($p))"'
  comm -3 <(jq -r "$leaves" "$here/policies.json" | sort) \
    <({ [[ -f "$installed" ]] && plutil -convert json -o - "$installed" || echo '{}'; } |
      jq -r "$leaves" | sort) |
    awk -F'\t' '$1 != "" { print $1 " is missing"; next } { print $2 " isn\047t in policies.json" }'
  exit 0
fi

out="$(mktemp -d)/Helium policies.mobileconfig"
jq --arg domain "$domain" '{
  PayloadType: "Configuration",
  PayloadVersion: 1,
  PayloadIdentifier: "local.helium.policies",
  PayloadUUID: "86C81DCF-0B82-4CBA-8BA3-24F9246F8BC7",
  PayloadDisplayName: "Helium policies",
  PayloadDescription: "helium/policies.json from MyConfigurations",
  PayloadScope: "System",
  PayloadContent: [. + {
    PayloadType: $domain,
    PayloadVersion: 1,
    PayloadIdentifier: "local.helium.policies.\($domain)",
    PayloadUUID: "F6378370-8915-49A2-A88D-633B4DD78BC9",
    PayloadDisplayName: "Helium"
  }]
}' "$here/policies.json" | plutil -convert xml1 -o "$out" -
plutil -lint "$out" >/dev/null
open "$out"
open 'x-apple.systempreferences:com.apple.Profiles-Settings.extension'
echo "Opened ${out/#$HOME/~}: install it in System Settings → General → Device Management"
