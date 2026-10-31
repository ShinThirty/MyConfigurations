# What an update can quietly reset. pacman never does: it leaves a config you
# changed alone and writes a .pacnew, which 20-pacman merges. Windows Update can,
# on this dual-boot machine, by putting Windows Boot Manager first in the
# firmware's boot order (MIGRATION.windows.md section 4). And the firewall,
# LLMNR, SMB signing and logins, and KeePassXC's Secret Service SECURITY.md has
# you set up, and the DNS over TLS MIGRATION.arch.md section 1 does, which Arch
# doesn't come with. And KeePassXC's settings from keepassxc/keepassxc.ini, and
# its start at login, and the night light's timer.

update() {
  info 'Settings'
  # ufw starts at boot only with its unit enabled, and filters only with
  # ENABLED=yes, which `ufw enable` writes
  if systemctl is-enabled --quiet ufw.service 2>/dev/null &&
     grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null; then
    ok 'ufw is on'
  else
    warn 'no firewall, listed below'
    todo+=('Security: ufw is off or not installed, so every port that listens is open to the network (SECURITY.md section 2)')
  fi

  # systemd-resolved asks the whole network by LLMNR for a name DNS doesn't
  # know, and takes the first answer, unless a drop-in turns it off
  if ! systemctl is-active --quiet systemd-resolved.service ||
     resolvectl status 2>/dev/null | awk '/^Global/,/^$/' | grep -q -- '-LLMNR'; then
    ok 'LLMNR is off'
  else
    warn 'LLMNR is on, listed below'
    todo+=("Security: systemd-resolved asks the network by LLMNR for names DNS doesn't know, and any device there can answer (SECURITY.md section 3)")
  fi

  # Linux's SMB client signs only when the server requires it, and the
  # router's share doesn't. Root does the mount, so a login in /etc/fstab,
  # which every account can read, or in a credentials file you can read, is
  # one any program running as you can read too
  local share opts cred shares=0 unsigned=() exposed=() o=()
  findmnt --fstab -t cifs,smb3 -rno TARGET,OPTIONS | while read -r share opts; do
    (( shares++ ))
    [[ ,$opts, == *,sign,* ]] || unsigned+=($share)
    o=(${(s:,:)opts})
    cred=${${(M)o:#(cred|credentials)=*}#*=}
    [[ -n ${(M)o:#(pass|password|password2)=*} || ( -n $cred && -r $cred ) ]] &&
      exposed+=($share)
  done
  if (( $#unsigned )); then
    warn "${(j:, :)unsigned} mounts unsigned, listed below"
    todo+=("Security: ${(j:, :)unsigned} mounts without sign in /etc/fstab, so a device on the network can change what's read from it (SECURITY.md section 3)")
  elif (( shares )); then
    ok 'SMB shares mount signed'
  fi
  if (( $#exposed )); then
    warn "${(j:, :)exposed}'s login is readable without root, listed below"
    todo+=("Security: ${(j:, :)exposed}'s login is in /etc/fstab or a credentials file you can read, so any program running as you can read it too; move it to a file only root can read (SECURITY.md section 3)")
  elif (( shares )); then
    ok "SMB shares' logins are readable only by root"
  fi

  # MIGRATION.arch.md section 1: systemd-resolved sends every lookup over TLS,
  # with no plain fallback, and /etc/resolv.conf points at it, so the programs
  # that read that file go through it too. A link's mode is the global one
  # unless NetworkManager's connection sets its own
  local line scope mode global servers plain=()
  if ! systemctl is-active --quiet systemd-resolved.service; then
    plain+=("systemd-resolved isn't running, so lookups go out in plain text: section 1's commands start it")
  else
    resolvectl dnsovertls 2>/dev/null | while IFS= read -r line; do
      scope=${line%: *} mode=${line##*: }
      if [[ $scope == Global ]]; then
        global=$mode
        [[ $mode == yes ]] ||
          plain+=("systemd-resolved's DNS over TLS is $mode, so lookups can go out in plain text: section 1's drop-in sets yes")
      elif [[ $global == yes && $mode != yes ]]; then
        # a link with no DNS servers of its own sends no lookups
        servers=$(resolvectl dns ${${scope#*\(}%\)} 2>/dev/null)
        [[ -n ${servers#*:} ]] &&
          plain+=("$scope has DNS over TLS $mode, so lookups to its DNS servers can go out in plain text: set its NetworkManager connection's connection.dns-over-tls back to default")
      fi
    done
  fi
  [[ /etc/resolv.conf -ef /run/systemd/resolve/stub-resolv.conf ]] ||
    plain+=("/etc/resolv.conf doesn't point at systemd-resolved, so the programs that read it look up names in plain text: section 1's ln line links it")
  if (( $#plain )); then
    warn 'DNS goes out in plain text, listed below'
    for line in $plain; do todo+=("Security: $line (MIGRATION.arch.md section 1)"); done
  else
    ok 'DNS goes over TLS'
  fi

  # SECURITY.md section 7: KeePassXC doubles as the keychain. Apps keep their
  # secrets in its Login database, through its Secret Service, which is off by
  # default. Without one, gh logs in with its token in plain text in hosts.yml
  local ini=${XDG_CONFIG_HOME:-$HOME/.config}/keepassxc/keepassxc.ini
  if (( $+commands[keepassxc] )); then
    if [[ $(awk -F= '/^\[/ { s = $0; next } s == "[FdoSecrets]" && $1 == "Enabled" { print $2 }' $ini 2>/dev/null) == true ]]; then
      ok "KeePassXC's Secret Service is on"
    else
      warn "KeePassXC's Secret Service is off, listed below"
      todo+=("Security: KeePassXC's Secret Service is off, so apps have no keychain to keep their secrets in: Settings → Secret Service Integration (SECURITY.md section 7)")
    fi
    local changed=(${(f)"$($DOTFILES/keepassxc/apply-settings.sh --check)"})
    if (( $#changed )); then
      warn "KeePassXC's settings changed, listed below"
      todo+=("Reset: KeePassXC's "${^changed}" (rerun keepassxc/apply-settings.sh, MIGRATION.arch.md section 2)")
    else
      ok "KeePassXC's settings are keepassxc.ini's"
    fi
    # Hyprland's user_startup.lua starts it at login with the main database
    # and the Login one, the entry arch/kooldots-upgrade.sh puts back when
    # KooL's upgrade drops it. A commented-out one starts with --
    local startup=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/user_startup.lua
    local entry='"gdbus wait --session --timeout 30 org.kde.StatusNotifierWatcher; keepassxc --minimized /mnt/tp-share/Password/shinthirty.kdbx $HOME/.local/share/keepassxc/login.kdbx",'
    local active=(${(f)"$(grep -E '^[[:space:]]*"[^"]*keepassxc ' $startup 2>/dev/null)"})
    if (( $#active == 1 )) && [[ ${active[1]#"${active[1]%%[![:space:]]*}"} == "$entry" ]]; then
      ok 'KeePassXC starts at login with both databases'
    elif (( ! $#active )); then
      warn "KeePassXC doesn't start at login, listed below"
      todo+=("Reset: Hyprland's user_startup.lua doesn't start KeePassXC, so apps find no keychain at login; arch/kooldots-upgrade.sh --post-only puts its entry back (MIGRATION.arch.md section 2)")
    else
      warn 'KeePassXC starts at login differently, listed below'
      todo+=("Reset: Hyprland's user_startup.lua starts KeePassXC with an entry other than arch/kooldots-upgrade.sh's, which opens the main database and then Login's, so Login's is the default for new secrets; its --post-only puts that entry back (MIGRATION.arch.md section 2)")
    fi
  fi
  local hosts=${GH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gh}/hosts.yml
  if grep -q 'oauth_token:' $hosts 2>/dev/null; then
    warn "gh's token is in plain text, listed below"
    todo+=("Security: gh's GitHub token is in plain text in $hosts; with KeePassXC's Login database unlocked, gh auth logout, then gh auth login, moves it there (SECURITY.md section 7)")
  elif [[ -f $hosts ]]; then
    ok "gh's token isn't in plain text"
  fi

  # arch/nightlight.sh turns the night light on at sunset through KooL's
  # Hyprsunset.sh, which a KooL upgrade can rename or drop
  local night=(${(f)"$($DOTFILES/arch/nightlight.sh --check)"})
  if (( $#night )); then
    warn "the night light doesn't follow the sun, listed below"
    todo+=("Night light: "${^night}" (MIGRATION.arch.md section 2)")
  else
    ok 'the night light follows the sun'
  fi

  [[ -d /sys/firmware/efi ]] || { skip 'not booted with UEFI'; return }
  # bootctl lists the boot order's entries first, in order; the first active one boots
  local first=$(bootctl status 2>/dev/null | awk '
    /^Boot Loaders Listed in EFI Variables/ { on = 1 }
    on && /Title:/ { sub(/.*Title: /, ""); title = $0 }
    on && /Status: active/ { print title; exit }')
  if [[ -z $first ]]; then
    warn "couldn't read the boot order from bootctl status"
  elif [[ $first == 'Linux Boot Manager' ]]; then
    ok 'systemd-boot is still first in the boot order'
  else
    warn "$first boots first, listed below"
    todo+=("Reset: $first is first in the boot order, not Linux Boot Manager; sudo bootctl install puts systemd-boot back (MIGRATION.windows.md section 4)")
  fi
}
