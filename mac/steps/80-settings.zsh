# What a macOS update can quietly reset: the login shell's PATH, the settings
# MIGRATION.md and SECURITY.md have you make by hand, Helium's policies, and
# KeePassXC's settings, launch agent and read-only copy of the database

update() {
  info 'Settings'
  local drift=()
  # A macOS update can replace /etc/zprofile or /etc/paths, which decide whether
  # Homebrew comes before /usr/bin (MIGRATION.md section 5). Checked in a real
  # login shell, as bootstrap.sh does.
  local resolved=$(zsh -lic 'command -v git' 2>/dev/null | tr -d '\r')
  [[ $resolved == $(brew --prefix)/* ]] ||
    drift+=("git resolves to ${resolved:-nothing} in a login shell, not Homebrew's (MIGRATION.md section 5)")

  # Domain, key, the value defaults should read, and what to do when it doesn't
  local settings=(
    NSGlobalDomain com.apple.swipescrolldirection 0
    'natural scrolling is on again: turn it off in System Settings → Mouse (MIGRATION.md section 1)'
    com.apple.spaces spans-displays 1
    'displays have separate Spaces again: turn it off in System Settings → Desktop & Dock, then log out (MIGRATION.md section 1)'
    com.apple.WindowManager EnableTilingByEdgeDrag 0
    'dragging a window to a screen edge tiles it again: turn it off in System Settings → Desktop & Dock (MIGRATION.md section 1)'
    com.apple.WindowManager EnableTopTilingByEdgeDrag 0
    'dragging a window to the menu bar fills the screen again: turn it off in System Settings → Desktop & Dock (MIGRATION.md section 1)'
    com.apple.dock expose-group-apps 1
    'Mission Control no longer groups windows by app: turn it on in System Settings → Desktop & Dock (MIGRATION.md section 1)'
    com.apple.desktopservices DSDontWriteNetworkStores 1
    'Finder writes .DS_Store files to network shares again (MIGRATION.md section 1): defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
  )
  local domain key want fix
  for domain key want fix in $settings; do
    [[ $(defaults read $domain $key 2>/dev/null) == $want ]] || drift+=($fix)
  done

  # SECURITY.md's, which take a command each to read. Listed apart from the
  # drift, since some may never have been set.
  local insecure=() fw=/usr/libexec/ApplicationFirewall/socketfilterfw
  # sysadminctl prints its answer as a log line, on stderr
  [[ $(sysadminctl -screenLock status 2>&1) == *'screenLock delay is immediate'* ]] ||
    insecure+=('the password isn'\''t required as soon as the screen locks: System Settings → Lock Screen (SECURITY.md section 1)')
  # State 1 is on, 2 is on and blocking everything
  [[ $($fw --getglobalstate) == *'(State = '[12]')'* ]] ||
    insecure+=("the firewall is off: sudo $fw --setglobalstate on (SECURITY.md section 2)")
  [[ $($fw --getstealthmode) == *' is on'* ]] ||
    insecure+=("stealth mode is off: sudo $fw --setstealthmode on (SECURITY.md section 2)")
  # The firewall lets Apple's own services through, so AirPlay Receiver has to
  # be off itself. ControlCenter listens on 7000 while it's on.
  lsof -nP -iTCP:7000 -sTCP:LISTEN 2>/dev/null | grep -q '^ControlCe' &&
    insecure+=('AirPlay Receiver is on: System Settings → General → AirDrop & Handoff (SECURITY.md section 3)')
  local updates=/Library/Preferences/com.apple.SoftwareUpdate
  for key in CriticalUpdateInstall ConfigDataInstall; do
    [[ $(defaults read $updates $key 2>/dev/null) == 1 ]] ||
      insecure+=("$key is off: turn on Security Responses and system files in System Settings → General → Software Update → Automatic Updates (SECURITY.md section 4)")
  done
  # Section 3: a mounted share's host in /etc/hosts, so the Mac doesn't ask the
  # whole network for it. A name with a dot, or an address, goes to DNS instead.
  local host
  for host in $(mount -t smbfs | awk '{ sub("^//([^@/]*@)?", "", $1); sub("/.*", "", $1); print tolower($1) }' | sort -u); do
    [[ $host == *[.:]* ]] ||
      awk -v h=$host '{ sub("#.*", ""); for (i = 2; i <= NF; i++) if (tolower($i) == h) found = 1 } END { exit !found }' /etc/hosts ||
      insecure+=("$host, a mounted share's host, isn't in /etc/hosts, so the Mac asks the whole network for it (SECURITY.md section 3)")
  done
  # And the SMB client asks the network for no name at all, and speaks only SMB 2
  # or later, signed: each line, and what's left without it
  local nsmb=(
    port445=no_netbios 'the SMB client asks the whole network for a name DNS and /etc/hosts don'\''t know'
    protocol_vers_map=6 'the SMB client still offers SMB 1'
    signing_required=yes 'the SMB client accepts a connection a device in between can change'
  )
  for key fix in $nsmb; do
    grep -qsx $key /etc/nsmb.conf || insecure+=("$fix: add $key to /etc/nsmb.conf (SECURITY.md section 3)")
  done
  # Section 9: lookups go to Cloudflare over HTTPS on any network, from a
  # configuration profile mac/dns-over-https.sh builds
  local line
  for line in ${(f)"$($DOTFILES/mac/dns-over-https.sh --check)"}; do
    insecure+=("the DNS over HTTPS profile $line (SECURITY.md section 9)")
  done

  # Helium's policies come from a configuration profile built from
  # helium/policies.json (MIGRATION.md section 3)
  if [[ -d /Applications/Helium.app ]]; then
    for line in ${(f)"$($DOTFILES/helium/apply-policies.sh --check)"}; do
      drift+=("Helium's policy $line (rerun helium/apply-policies.sh, MIGRATION.md section 3)")
    done
  fi
  # keepassxc/keepassxc.ini's settings, the launch agent that opens it at login,
  # and the read-only local copy of the database
  if [[ -d /Applications/KeePassXC.app ]]; then
    for line in ${(f)"$($DOTFILES/keepassxc/apply-settings.sh --check)"}; do
      drift+=("KeePassXC's $line (rerun keepassxc/apply-settings.sh, MIGRATION.md section 3)")
    done
    for line in ${(f)"$($DOTFILES/keepassxc/sync.sh --check)"}; do
      drift+=("KeePassXC's $line (run keepassxc/sync.sh, MIGRATION.md section 4)")
    done
  fi

  if (( $#drift )); then
    warn "$#drift changed, listed below"
    todo+=("Reset: "${^drift})
  else
    ok "git resolves to $resolved; the settings MIGRATION.md makes, Helium's policies and KeePassXC's settings are as set"
  fi
  if (( $#insecure )); then
    warn "$#insecure of SECURITY.md's settings not as it says, listed below"
    todo+=("Security: "${^insecure})
  else
    ok "SECURITY.md's settings are as set"
  fi
}
