# What an update can quietly reset. pacman never does: it leaves a config you
# changed alone and writes a .pacnew, which 20-pacman merges. Windows Update can,
# on this dual-boot machine, by putting Windows Boot Manager first in the
# firmware's boot order (MIGRATION.windows.md section 4). And the firewall
# SECURITY.md has you set up, which Arch doesn't come with.

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
