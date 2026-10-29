# aria2's installed copies (aria2/darwin). install.sh copies them rather than
# links them, since the tracker refresh rewrites aria2.conf, so a change in the
# repo reaches this Mac only through this step.

update() {
  info 'aria2'
  local dir=${XDG_CONFIG_HOME:-$HOME/.config}/aria2
  if (( ! $+commands[aria2c] )) || [[ ! -f $dir/aria2.conf ]]; then
    skip 'not set up here'
    return
  fi

  # Pairs of the repo's file and its installed copy
  local agents=$HOME/Library/LaunchAgents
  local copies=(
    aria2/aria2_update_tracker.sh $dir/aria2_update_tracker.sh
    aria2/darwin/com.aria2.plist $agents/com.aria2.plist
    aria2/darwin/com.aria2.regular.tracker.update.plist $agents/com.aria2.regular.tracker.update.plist
  )
  local src dst changed=()
  for src dst in $copies; do
    cmp -s $DOTFILES/$src $dst && continue
    cp $DOTFILES/$src $dst && changed+=(${dst:t})
  done

  # The installed aria2.conf has two lines the repo's lacks: the rpc-secret=
  # install.sh adds, and the bt-tracker= the weekly refresh writes. The rest
  # should match, so it's rewritten from the repo's with those lines kept.
  local repo_conf=$DOTFILES/aria2/aria2.conf own='^(rpc-secret|bt-tracker)='
  if [[ "$(grep -Ev $own $repo_conf)" != "$(grep -Ev $own $dir/aria2.conf)" ]]; then
    local merged=$(grep -Ev $own $repo_conf; grep -E $own $dir/aria2.conf)
    print -r -- $merged >$dir/aria2.conf && changed+=(aria2.conf)
  fi
  grep -q '^rpc-secret=.' $dir/aria2.conf ||
    todo+=('aria2: its RPC has no secret, so a web page can tell it what to download and where: SECURITY.md section 6')

  if (( $#changed )); then
    ok "updated from the repo: $changed"
  else
    ok 'the installed copies match the repo'
  fi

  local restart=$(( ${changed[(Ie)aria2.conf]} )) label
  for label in com.aria2 com.aria2.regular.tracker.update; do
    if ! launchctl print gui/$UID/$label &>/dev/null; then
      todo+=("aria2: $label isn't loaded: launchctl load ~/Library/LaunchAgents/$label.plist")
    elif (( ${changed[(Ie)$label.plist]} )); then
      launchctl unload $agents/$label.plist && launchctl load $agents/$label.plist &&
        ok "reloaded $label"
      # Loading com.aria2 starts aria2 again, on the new aria2.conf too
      [[ $label == com.aria2 ]] && restart=0
    fi
  done
  (( restart )) && launchctl kickstart -k gui/$UID/com.aria2 && ok 'restarted aria2 on the new aria2.conf'
}
