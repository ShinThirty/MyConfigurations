if (( $+commands[fzf] )); then
    # Set up fzf key bindings and fuzzy completion
    eval "$(fzf --zsh)"

    alias rfv="$DOTFILES/zsh/rfv"

    # Use ~~ as the trigger sequence instead of the default **
    export FZF_COMPLETION_TRIGGER='~~'

    # Use fd (https://github.com/sharkdp/fd) instead of the default find
    # command for listing path candidates.
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
        alias fzp="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"
    fi
fi
