# Set ZSH_CACHE_DIR
export ZSH_CACHE_DIR="$HOME/.cache"

# Create cache and completions dir and add to $fpath
mkdir -p "$ZSH_CACHE_DIR/completions"
(( ${fpath[(Ie)"$ZSH_CACHE_DIR/completions"]} )) || fpath=("$ZSH_CACHE_DIR/completions" $fpath)

# Change XDG_CONFIG_HOME
export XDG_CONFIG_HOME="$HOME/.config"

# Setup GPG_TTY
export GPG_TTY=$TTY

# Use extended globbing
setopt extendedglob

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

zmodload zsh/net/tcp

# Use nano as the default editor
export VISUAL=nano
export EDITOR="$VISUAL"

if (( $+commands[fzf] )); then
    # Set up fzf key bindings and fuzzy completion
    eval "$(fzf --zsh)"

    alias rfv="$MY_CONFIG_ROOT/zsh/rfv"
    source "$MY_CONFIG_ROOT/fzf-git/fzf-git.sh"

    # Use ~~ as the trigger sequence instead of the default **
    export FZF_COMPLETION_TRIGGER='~~'

    export FZF_COMPLETION_OPTS='--border --info=inline'

    # Use fd (https://github.com/sharkdp/fd) instead of the default find
    # command for listing path candidates.
    # - The first argument to the function ($1) is the base path to start traversal
    # - See the source code (completion.{bash,zsh}) for the details.
    _fzf_compgen_path() {
        fd --hidden --follow --exclude ".git" . "$1"
    }

    # Use fd to generate the list for directory completion
    _fzf_compgen_dir() {
        fd --type d --hidden --follow --exclude ".git" . "$1"
    }

    # Setting up fzf default options
    export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --info=inline --border --margin=1 --padding=1'

    # Setting fd as the default source for fzf
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'

    # To apply the command to CTRL-T as well
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

    if (( $+commands[bat] )); then
        # Use bat as the previewer for fzf
        alias fzp="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"

        # Bat theme
        export BAT_THEME='gruvbox-dark'
    fi
fi

# Setup zoxide
if (( $+commands[zoxide] )); then
    z() {
        unfunction "$0"
        eval "$(zoxide init zsh)"
        __zoxide_z "$@"
    }
fi

if (( $+commands[cheat] )); then
    # Cheat integration with FZF
    export CHEAT_USE_FZF=true
fi

# Setup nnn
if (( $+commands[nnn] )); then
    alias nnn_update_plugins='sh -c "$(curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs)"'
    export NNN_FIFO=/tmp/nnn.fifo
    export NNN_PLUG='p:-preview-tui'
fi

# Use eza as ls if eza is installed
if (( $+commands[eza] )); then
    alias ls='eza'
    alias l='eza -l --all --group-directories-first --git'
    alias lt='eza -T --git-ignore --level=2 --group-directories-first'
    alias llt='eza -lT --git-ignore --level=2 --group-directories-first'
    alias lT='eza -T --git-ignore --level=4 --group-directories-first'
fi

# Enable locate on MacOS
if which glocate > /dev/null; then
    alias locate="glocate -d $HOME/locatedb"

    # Using cache_list requires `LOCATE_PATH` environment var to exist in session.
    # trouble shoot: `echo $LOCATE_PATH` needs to return db path.
    [[ -f "$HOME/locatedb" ]] && export LOCATE_PATH="$HOME/locatedb"
fi

alias loaddb="gupdatedb --localpaths=$HOME --prunepaths=/Volumes --output=$HOME/locatedb"
