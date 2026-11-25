#!/usr/bin/env bash
#
# Makes Caps Lock Esc on every keyboard connected, for this user (MIGRATION.md
# section 1). macOS saves modifier keys per keyboard, under its vendor and
# product IDs: the mappings System Settings → Keyboard → Keyboard Shortcuts →
# Modifier Keys shows. A keyboard's other mappings stay as they are. An external
# keyboard takes the new mapping when it's plugged in again, a built-in one at
# the next login.
#
# --check writes nothing; it names each keyboard connected whose Caps Lock
# isn't Esc instead. mac/steps/80-settings.zsh runs it.
#
set -euo pipefail

# HID usages: Caps Lock is 0x700000039, Esc 0x700000029
caps=30064771129
esc=30064771113

# Each keyboard connected, as 'vendor-product<TAB>Yes or No for built in<TAB>
# name', the IDs in decimal, as the saved mappings' names have them. A keyboard
# is a HID service with usage page 1, usage 6, and ioreg lists a device once
# for each such service.
keyboards() {
  ioreg -r -k HIDEventServiceProperties -d 1 -w0 | awk -F' = ' '
    function out() { if (page == 1 && usage == 6) print vid "-" pid "\t" (builtin == "Yes" ? "Yes" : "No") "\t" name }
    /^\+-o/ { out(); page = usage = vid = pid = builtin = name = "" }
    $1 ~ /^ *"PrimaryUsagePage"$/ { page = $2 }
    $1 ~ /^ *"PrimaryUsage"$/ { usage = $2 }
    $1 ~ /^ *"VendorID"$/ { vid = $2 }
    $1 ~ /^ *"ProductID"$/ { pid = $2 }
    $1 ~ /^ *"Built-In"$/ { builtin = $2 }
    $1 ~ /^ *"Product"$/ { name = $2; gsub(/^"|"$/, "", name) }
    END { out() }' | sort -u
}

while IFS=$'\t' read -r kbd builtin name; do
  key=com.apple.keyboard.modifiermapping.$kbd-0
  # The saved mappings as JSON, [] for none. defaults prints them as an
  # old-style plist, whose numbers plutil reads as strings.
  saved="$(defaults -currentHost read -g "$key" 2>/dev/null |
    plutil -convert json -o - - 2>/dev/null)" || saved='[]'
  saved="$(jq -c 'map(map_values(tonumber))' <<<"$saved")"
  jq -e --argjson caps $caps --argjson esc $esc \
    'any(.HIDKeyboardModifierMappingSrc == $caps and .HIDKeyboardModifierMappingDst == $esc)' \
    <<<"$saved" >/dev/null && continue
  if [[ ${1-} == --check ]]; then
    echo "$name"
    continue
  fi
  # The other mappings, and Caps Lock to Esc, each as the XML defaults takes
  dicts=()
  while read -r dict; do
    dicts+=("$dict")
  done < <(jq -r --argjson caps $caps --argjson esc $esc '
    map(select(.HIDKeyboardModifierMappingSrc != $caps))
    + [{HIDKeyboardModifierMappingSrc: $caps, HIDKeyboardModifierMappingDst: $esc}]
    | .[] | "<dict><key>HIDKeyboardModifierMappingDst</key><integer>\(.HIDKeyboardModifierMappingDst)</integer><key>HIDKeyboardModifierMappingSrc</key><integer>\(.HIDKeyboardModifierMappingSrc)</integer></dict>"' \
    <<<"$saved")
  defaults -currentHost write -g "$key" -array "${dicts[@]}"
  if [[ $builtin == Yes ]]; then
    echo "Caps Lock is Esc on $name from the next login"
  else
    echo "Caps Lock is Esc on $name once it's plugged in again"
  fi
done < <(keyboards)
