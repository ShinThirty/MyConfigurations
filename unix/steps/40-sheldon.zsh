# The zsh plugins

update() {
  info 'zsh plugins'
  (( $+commands[sheldon] )) || { skip 'sheldon not installed'; return }
  # zshrc asks every 14 days on its own; resetting its timer keeps it from asking next
  if SHELDON_CONFIG_DIR=$DOTFILES/sheldon sheldon lock --update; then
    date +%s >${XDG_CACHE_HOME:-$HOME/.cache}/sheldon_last_update
  else
    todo+=('sheldon lock --update failed: read its output above')
  fi
}
