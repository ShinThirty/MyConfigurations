# aria2's installed copies (aria2/linux). install.sh copies them rather than
# links them, since the tracker refresh rewrites aria2.conf, so a change in the
# repo reaches this machine only through this step.

update() {
  info 'aria2'
  local config=${XDG_CONFIG_HOME:-$HOME/.config}
  local dir=$config/aria2
  if (( ! $+commands[aria2c] )) || [[ ! -f $dir/aria2.conf ]]; then
    skip 'not set up here'
    return
  fi

  # Pairs of the repo's file and its installed copy
  local units=$config/systemd/user
  local copies=(
    aria2/aria2_update_tracker.sh $dir/aria2_update_tracker.sh
    aria2/linux/aria2.service $units/aria2.service
    aria2/linux/aria2_update_tracker.service $units/aria2_update_tracker.service
    aria2/linux/aria2_update_tracker.timer $units/aria2_update_tracker.timer
  )
  local src dst changed=()
  for src dst in $copies; do
    cmp -s $DOTFILES/$src $dst && continue
    cp $DOTFILES/$src $dst && changed+=(${dst:t})
  done

  # The installed aria2.conf has the bt-tracker= line the weekly refresh writes,
  # which the repo's lacks. The rest should match, so it's rewritten from the
  # repo's with that line kept.
  local repo_conf=$DOTFILES/aria2/aria2.conf
  if [[ "$(grep -v '^bt-tracker=' $repo_conf)" != "$(grep -v '^bt-tracker=' $dir/aria2.conf)" ]]; then
    local merged=$(grep -v '^bt-tracker=' $repo_conf; grep '^bt-tracker=' $dir/aria2.conf)
    print -r -- $merged >$dir/aria2.conf && changed+=(aria2.conf)
  fi

  if (( $#changed )); then
    ok "updated from the repo: $changed"
  else
    ok 'the installed copies match the repo'
  fi

  (( ${#${(M)changed:#*.(service|timer)}} )) && systemctl --user daemon-reload
  # Only a running aria2 is restarted: a stopped one starts on the new files.
  # try-restart would do the same, but exits 0 either way.
  if (( ${changed[(Ie)aria2.conf]} || ${changed[(Ie)aria2.service]} )) &&
     systemctl --user is-active --quiet aria2.service; then
    systemctl --user restart aria2.service && ok 'restarted aria2'
  fi
  # try-restart leaves a stopped unit stopped
  (( ${changed[(Ie)aria2_update_tracker.timer]} )) && systemctl --user try-restart aria2_update_tracker.timer
  local unit
  for unit in aria2.service aria2_update_tracker.timer; do
    systemctl --user is-enabled --quiet $unit ||
      todo+=("aria2: $unit isn't enabled: systemctl --user enable --now $unit")
  done
}
