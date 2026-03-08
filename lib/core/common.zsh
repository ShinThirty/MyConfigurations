# Cache directory for plugins
export ZSH_CACHE_DIR="$HOME/.cache"
mkdir -p "$ZSH_CACHE_DIR/completions"
(( ${fpath[(Ie)"$ZSH_CACHE_DIR/completions"]} )) || fpath=("$ZSH_CACHE_DIR/completions" $fpath)

# Change XDG_CONFIG_HOME
export XDG_CONFIG_HOME="$HOME/.config"

# Setup GPG_TTY
export GPG_TTY=$TTY

# Use extended globbing
setopt extendedglob

# Use vim as the default editor
export VISUAL=vim
export EDITOR="$VISUAL"

# less auto exits
alias less="less -FRX"

# Measure zsh startup time
timezsh() {
    shell=${1-$SHELL}
    for _ in $(seq 1 10); do /usr/bin/time "$shell" -i -c exit; done
}

