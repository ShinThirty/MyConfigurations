#!/usr/bin/env bash
#
# Merges preferences.json, then preferences.<os>.json, into Helium's Default
# profile. None of these settings has a policy, so they live in the profile's
# own Preferences file, which Helium rewrites on exit; close it first. Keys the
# fragments don't name are left alone, so rerunning is harmless. The previous
# file is kept as Preferences.bak.
#
#   preferences.json        every platform: Helium's layout and zen mode, the
#                           profile's name and avatar
#   preferences.linux.json  the fonts; the page languages, which Blink also uses
#                           to pick the CJK font for text without a lang
#                           attribute; the Classic theme (system_theme 0); and
#                           Google as the search engine, a signed setting that
#                           Windows and macOS reset when it's edited
#   preferences.darwin.json the page languages, Edge's; Edge set no fonts, so
#                           they stay Chromium's defaults
#
# It also makes a new tab open newtab.html, from the repo, through Helium's
# custom-ntp flag in Local State, giving it ~/.config/helium-newtab, where
# links.js is, as ?dir=. The paths are this machine's, so they're not in a
# fragment. The NewTabPageLocation policy would do the same, but Chromium
# ignores it on a Mac or Windows PC that no organization manages.
#
# --check writes nothing; it lists what keeps a new tab from opening
# newtab.html instead, and the platform's steps/80-settings.zsh runs it. It
# doesn't check the fragments' settings.
#
# To record a setting changed in Helium's settings, diff Preferences from
# before the change and after Helium closes.
#
set -euo pipefail

# -P, so the page's address is the same however the script was reached
here="$(cd "$(dirname "$0")" && pwd -P)"

case "$OSTYPE" in
  linux*)
    fragment="$here/preferences.linux.json"
    data="${HELIUM_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/net.imput.helium"
    process=helium
    ;;
  darwin*)
    fragment="$here/preferences.darwin.json"
    data="$HOME/Library/Application Support/net.imput.helium"
    process=Helium
    ;;
  *)
    echo "No preferences fragment for $OSTYPE yet" >&2
    exit 1
    ;;
esac
prefs="$data/Default/Preferences"
state="$data/Local State"
ntp="file://$here/newtab.html?dir=file://$HOME/.config/helium-newtab/"

if [[ ${1-} == --check ]]; then
  if [[ ! -f $state ]]; then
    echo "Local State, ${state/#$HOME/~}, isn't there yet"
    exit 0
  fi
  on="$(jq '.browser.enabled_labs_experiments // [] | any(. == "custom-ntp")' "$state")"
  url="$(jq -r '.browser.enabled_labs_experiments_origin_lists["custom-ntp"] // ""' "$state")"
  if [[ $on != true ]]; then
    echo "new tab page flag, custom-ntp, is off, so a new tab opens Chromium's page of the sites visited most"
  elif [[ $url != "$ntp" ]]; then
    echo "new tab page flag, custom-ntp, opens ${url:-nothing}, not $ntp"
  fi
  exit 0
fi

if [[ ! -f "$prefs" ]]; then
  echo "No profile at $prefs yet: start Helium once, then close it" >&2
  exit 1
fi
if pgrep -x "$process" >/dev/null; then
  echo "Helium is running and would overwrite the merge on exit; close it first" >&2
  exit 1
fi

cp -p "$prefs" "$prefs.bak"
tmp="$(mktemp "$prefs.XXXXXX")"
jq -c -s '.[0] * .[1] * .[2]' "$prefs" "$here/preferences.json" "$fragment" >"$tmp"
mv "$tmp" "$prefs"
echo "Merged preferences.json and ${fragment##*/} into ${prefs/#$HOME/~}"

# The profile menu shows the name and avatar from Local State's profile cache,
# which Helium doesn't refresh from Preferences on its own. The flags are there
# too, so the new tab page's is.
cp -p "$state" "$state.bak"
tmp="$(mktemp "$state.XXXXXX")"
jq -c --slurpfile f "$here/preferences.json" --arg ntp "$ntp" '
  .browser.enabled_labs_experiments |= (. // []) - ["custom-ntp"] + ["custom-ntp"]
  | .browser.enabled_labs_experiments_origin_lists["custom-ntp"] = $ntp
  | ($f[0].profile // {}) as $p
  | if $p.name then
      .profile.info_cache.Default += {name: $p.name, is_using_default_name: false}
    else . end
  | if $p.avatar_index then
      .profile.info_cache.Default += {
        avatar_icon: "chrome://theme/IDR_PROFILE_AVATAR_\($p.avatar_index)",
        is_using_default_avatar: false
      }
    else . end' "$state" >"$tmp"
mv "$tmp" "$state"
echo "Set the profile's name and avatar, and the new tab page, in ${state/#$HOME/~}"
