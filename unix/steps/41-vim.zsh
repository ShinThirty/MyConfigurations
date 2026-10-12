# vim-plug itself, and vim's plugins

update() {
  info 'vim plugins'
  (( $+commands[vim] )) || { skip 'vim not installed'; return }
  # vim-plug updates synchronously while vim is starting, so +qa waits for it.
  # PlugUpgrade reloads vim-plug when it replaces it, so PlugUpdate runs the new one
  vim +PlugUpgrade +PlugUpdate +qa
  # An upgrade replaces autoload/plug.vim, which the vim submodule tracks, and
  # keeps the old one beside it as plug.vim.old, which git has anyway
  rm -f $DOTFILES/vim/autoload/plug.vim.old
  if [[ -n $(git -C $DOTFILES/vim status --porcelain -- autoload/plug.vim) ]]; then
    ok 'vim-plug upgraded'
    todo+=('Commit the new vim/autoload/plug.vim in the vim submodule, then the submodule in the repo')
  fi
}
