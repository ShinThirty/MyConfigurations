#!/usr/bin/env zsh
#
# Turns the night light on at sunset and off at sunrise, through KooL's
# Hyprsunset.sh, the script behind waybar's night light button and SUPER+N, so
# the button shows what this did. It switches only when the sun crosses the
# horizon, so a click in between holds until the next sunrise or sunset.
# Run a minute after login and every 15 minutes by nightlight.timer, from the
# symlinks.linux links, so it switches within 15 minutes of sunset or sunrise.
#
# The location is the lock screen weather's: KooL's Weather.py finds it from
# the IP address and keeps it in ~/.cache/open_meteo_cache.json. Where that's
# wrong, as behind a VPN, ~/.config/nightlight/location takes its place: one
# line, latitude, then longitude, in decimal degrees, north and east positive,
# such as 51.5 -0.1. Either stays out of the repo, which is public.
#
# --check writes nothing; it lists what keeps the night light from following
# the sun instead. arch/steps/80-settings.zsh runs it.

zmodload zsh/mathfunc

location=${XDG_CONFIG_HOME:-$HOME/.config}/nightlight/location
weather=$HOME/.cache/open_meteo_cache.json
toggle=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/Hyprsunset.sh
phase_file=${XDG_STATE_HOME:-$HOME/.local/state}/nightlight/phase

read_location() {
  if [[ -s $location ]]; then
    read -r lat lon _ <$location
  else
    read -r lat lon <<<"$(jq -r '.forecast | "\(.latitude) \(.longitude)"' $weather 2>/dev/null)"
  fi
  [[ $lat == (-|)<->(.<->|) && $lon == (-|)<->(.<->|) ]] &&
    (( lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 ))
}

# NOAA's solar position formulas, for now in UTC: true while the sun's centre
# is more than 0.833° below the horizon, the depth that counts as sunset once
# the air's refraction and the sun's radius are allowed for
is_night() {
  local doy h m s
  read -r doy h m s <<<"$(date -u '+%-j %-H %-M %-S')"
  local -F rad=$(( 3.141592653589793 / 180 ))
  local -F hour=$(( h + m / 60.0 + s / 3600.0 ))
  local -F g=$(( 360.0 / 365 * (doy - 1 + (hour - 12) / 24) * rad ))
  # How far solar time runs ahead of the clock, in minutes
  local -F eqtime=$(( 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g)
    - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g)) ))
  local -F decl=$(( 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g)
    - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g)
    - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g) ))
  # The hour angle, how far the sun has turned from noon here
  local -F ha=$(( ((hour * 60 + eqtime + 4 * lon) / 4 - 180) * rad ))
  local -F phi=$(( lat * rad ))
  (( sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(ha) < cos(90.833 * rad) ))
}

if [[ ${1-} == --check ]]; then
  if [[ -s $location ]]; then
    read_location || print "${(D)location} isn't latitude, then longitude, such as 51.5 -0.1"
  elif ! read_location; then
    print "KooL's Weather.py has no location in ${(D)weather}, so it can't tell when the sun sets: write latitude, then longitude into ${(D)location}, such as 51.5 -0.1"
  fi
  [[ -x $toggle ]] ||
    print "KooL's ${(D)toggle} isn't there, so it has nothing to switch: point arch/nightlight.sh at what replaced it"
  { systemctl --user is-enabled --quiet nightlight.timer && systemctl --user is-active --quiet nightlight.timer } 2>/dev/null ||
    print "nightlight.timer isn't enabled and running: systemctl --user enable --now nightlight.timer"
  systemctl --user is-failed --quiet nightlight.service 2>/dev/null &&
    print "its last run failed: journalctl --user -u nightlight.service says why"
  exit 0
fi

read_location || { print -u2 "no location, from ${(D)location} or ${(D)weather}"; exit 1 }
is_night && phase=night || phase=day
[[ -f $phase_file && $(<$phase_file) == $phase ]] && exit 0

# Until Hyprland is up, and outside it, there's nothing to switch; the next run
# tries again
[[ -n ${WAYLAND_DISPLAY-} ]] && hyprctl version >/dev/null 2>&1 || exit 0

if [[ $phase == night ]]; then
  # on starts hyprsunset if it isn't running. systemd kills what's left in
  # this unit once the script exits, so it starts in a scope of its own
  systemd-run --user --scope --quiet --collect -- $toggle on
else
  $toggle off
fi || exit 1
mkdir -p ${phase_file:h}
print $phase >$phase_file
