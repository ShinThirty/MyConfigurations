# Cache directory for plugins
export ZSH_CACHE_DIR="$HOME/.cache"
mkdir -p "$ZSH_CACHE_DIR/completions"
(( ${fpath[(Ie)"$ZSH_CACHE_DIR/completions"]} )) || fpath=("$ZSH_CACHE_DIR/completions" $fpath)

typeset -U path

# macOS: `make` and `man make` are Homebrew's GNU Make 4, which it installs as
# gmake, ahead of the Command Line Tools' GNU Make 3.81. MANPATH is prepended as
# a string: its empty entries stand for man's default search path, and the
# $manpath array drops them
if [[ -n "$HOMEBREW_PREFIX" && -d "$HOMEBREW_PREFIX/opt/make/libexec/gnubin" ]]; then
    path=("$HOMEBREW_PREFIX/opt/make/libexec/gnubin" $path)
    [[ ":$MANPATH:" == *":$HOMEBREW_PREFIX/opt/make/libexec/gnuman:"* ]] ||
        export MANPATH="$HOMEBREW_PREFIX/opt/make/libexec/gnuman:$MANPATH"
fi

# Scripts symlinked out of this repo land here (see the `symlinks` map)
path=("$HOME/.local/bin" $path)

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

