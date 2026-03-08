# bat
if (( $+commands[bat] )); then
    export BAT_THEME='gruvbox-dark'
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

# yazi shell wrapper
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}
