# bat
if (( $+commands[bat] )); then
    export BAT_THEME='gruvbox-dark'
    alias batp='bat --style=plain'
fi

# zoxide
if (( $+commands[zoxide] )); then
    z() {
        unfunction "$0"
        eval "$(zoxide init zsh)"
        __zoxide_z "$@"
    }
fi

# eza
if (( $+commands[eza] )); then
    alias ls='eza'
    alias l='eza -l --all --group-directories-first --git'
    alias lt='eza -T --git-ignore --level=2 --group-directories-first'
    alias llt='eza -lT --git-ignore --level=2 --group-directories-first'
    alias lT='eza -T --git-ignore --level=4 --group-directories-first'
fi

# locate (macOS GNU locate)
if (( $+commands[glocate] )); then
    alias locate="glocate -d $HOME/locatedb"
    alias loaddb="gupdatedb --localpaths=$HOME --prunepaths=/Volumes --output=$HOME/locatedb"
    [[ -f "$HOME/locatedb" ]] && export LOCATE_PATH="$HOME/locatedb"
fi

# git bare repo dotfiles
if [[ -d "$HOME/.dotfiles.git" ]]; then
    alias cfg='git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME'
fi

# Keybinding cheatsheet
if (( $+commands[bat] )); then
    keys() { bat --style=plain "$DOTFILES/cheatsheet.md"; }
else
    keys() {
        cat "$DOTFILES/cheatsheet.md"
        printf '\n\033[33mTip: install bat for syntax-highlighted output\033[0m\n'
    }
fi

# yazi shell wrapper
if (( $+commands[yazi] )); then
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
        command rm -f -- "$tmp"
    }
fi
