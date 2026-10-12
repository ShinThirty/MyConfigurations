# What an update can quietly reset. pacman never does: it leaves a config you
# changed alone and writes a .pacnew, which 20-pacman merges. Windows Update can,
# on this dual-boot machine, by putting Windows Boot Manager first in the
# firmware's boot order (MIGRATION.windows.md section 4).

update() {
  info 'Settings'
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
