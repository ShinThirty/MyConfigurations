# vim-plug itself, and vim's plugins

update() {
  info 'vim plugins'
  (( $+commands[vim] )) || { skip 'vim not installed'; return }
  # Each plugin's commit before and after, to name the ones that moved
  local plugged=$DOTFILES/vim/plugged p before=() after=() moved=()
  for p in $plugged/*(N/); do before+=("${p:t} $(git -C $p rev-parse HEAD 2>/dev/null)"); done
  # vim-plug updates synchronously while vim is starting, so +qa waits for it.
  # PlugUpgrade reloads vim-plug when it replaces it, so PlugUpdate runs the new
  # one. vim clears the screen when it quits, so PlugUpdate's window is saved
  # first: it marks the plugins that failed with an x, their errors indented below
  local log=$(mktemp)
  vim +PlugUpgrade +PlugUpdate "+call writefile(getline(1, '\$'), '$log')" +qa
  local errors=(${(f)"$(awk '/^x /{e=1; print; next} e && /^    /{print; next} {e=0}' $log)"})
  rm -f $log
  for p in $plugged/*(N/); do after+=("${p:t} $(git -C $p rev-parse HEAD 2>/dev/null)"); done
  for p in ${after:|before}; do moved+=(${p%% *}); done

  # An upgrade replaces autoload/plug.vim, which the vim submodule tracks, and
  # keeps the old one beside it as plug.vim.old, which git has anyway
  rm -f $DOTFILES/vim/autoload/plug.vim.old
  if [[ -n $(git -C $DOTFILES/vim status --porcelain -- autoload/plug.vim) ]]; then
    ok 'vim-plug upgraded'
    todo+=('Commit the new vim/autoload/plug.vim in the vim submodule, then the submodule in the repo')
  fi
  if (( $#errors )); then
    print -rl -- $errors | sed 's/^/  /'
    todo+=('vim: PlugUpdate failed for the plugins above')
  fi
  if (( $#moved )); then ok "updated $moved"; elif (( ! $#errors )); then ok 'plugins up to date'; fi
}
