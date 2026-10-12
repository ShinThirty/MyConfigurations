# Whether the upgrade left a reboot due

update() {
  info 'Reboot'
  # Upgrading the kernel package deletes the running kernel's modules, and the
  # NVIDIA userspace stops talking to the loaded module until both match again
  local reasons=() loaded nvidia
  [[ -d /usr/lib/modules/$(uname -r) ]] || reasons+=("the running kernel $(uname -r) was replaced")
  if [[ -r /sys/module/nvidia/version ]]; then
    loaded=$(</sys/module/nvidia/version)
    nvidia=$(pacman -Q nvidia-utils 2>/dev/null | awk '{ sub(/-[^-]*$/, "", $2); print $2 }')
    [[ -z $nvidia || $nvidia == $loaded ]] || reasons+=("the NVIDIA driver went from $loaded to $nvidia")
  fi
  if (( $#reasons )); then
    warn 'due, listed below'
    todo+=("Reboot: "${^reasons})
  else
    ok 'not needed'
  fi
}
