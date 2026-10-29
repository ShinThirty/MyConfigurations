# The Wi-Fi networks the Mac remembers, which it joins again by name alone,
# anywhere, as does every Apple device iCloud syncs them to (SECURITY.md
# section 9). Offers to forget all but the ones listed one per line in
# ~/.config/wifi/keep, which stays out of this repo, since it's public.

cleanup() {
  info 'Wi-Fi networks'
  local dev=$(networksetup -listallhardwareports | awk '/Wi-Fi/ { getline; print $2 }')
  [[ -n $dev ]] || { skip 'no Wi-Fi'; return }
  local keep=~/.config/wifi/keep
  if [[ ! -s $keep ]]; then
    skip "no $keep, so none forgotten"
    todo+=("Security: list the Wi-Fi networks to keep in $keep, one per line, and the cleanup offers to forget the rest (SECURITY.md section 9)")
    return
  fi
  # A heading first, then each name after a tab
  local kept=(${(f)"$(<$keep)"}) remembered=(${${(f)"$(networksetup -listpreferredwirelessnetworks $dev)"}#$'\t'})
  shift remembered
  local forget=(${remembered:|kept})
  if (( ! $#forget )); then
    ok "remembers only networks in $keep"
    return
  fi
  warn "remembers $#forget not in $keep:"
  printf '      %s\n' $forget
  if [[ -t 0 ]] && read -q '?      Forget them? sudo asks for your password [y/N] '; then
    print
    local ssid
    for ssid in $forget; do
      sudo networksetup -removepreferredwirelessnetwork $dev $ssid >/dev/null
    done
    # networksetup exits 0 even when it fails, so ask it again
    remembered=(${${(f)"$(networksetup -listpreferredwirelessnetworks $dev)"}#$'\t'})
    local left=(${forget:*remembered})
    (( $#left )) || { ok "forgot ${(j:, :)forget}"; return }
    forget=($left)
  else
    [[ -t 0 ]] && print
  fi
  todo+=("Security: the Mac remembers Wi-Fi networks that aren't in $keep: ${(j:, :)forget}; mac/cleanup.sh offers to forget them, or System Settings → Wi-Fi (SECURITY.md section 9)")
}
