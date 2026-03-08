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

# Shortcut to exit shell on partial command line
exit_zsh() { exit }
zle -N exit_zsh
bindkey '^D' exit_zsh

# Clear the backbuffer with Ctrl+L
function clear-screen-and-scrollback() {
    echoti civis >"$TTY"
    printf '%b' '\e[H\e[2J' >"$TTY"
    zle .reset-prompt
    zle -R
    printf '%b' '\e[3J' >"$TTY"
    echoti cnorm >"$TTY"
}

zle -N clear-screen-and-scrollback
bindkey '^L' clear-screen-and-scrollback

# [Ctrl-Delete] - delete whole backward-word
bindkey '^H' backward-kill-word
