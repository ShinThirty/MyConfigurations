# less auto exits
alias less="less -FRX"

# Measure zsh startup time
timezsh() {
	shell=${1-$SHELL}
	for _ in $(seq 1 10); do /usr/bin/time "$shell" -i -c exit; done
}

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

# Use bat as the previewer for fzf
alias fzp="fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"

# Bat theme
export BAT_THEME='Dracula'

# Setup zoxide
z() {
	unfunction "$0"
	eval "$(zoxide init zsh)"
	$0 "$@"
}

# Cheat integration with FZF
export CHEAT_USE_FZF=true

# Lazy load cheat autocompletion
cheat() {
	unfunction "$0"
	# shellcheck source=/dev/null
	source "$HOME/.config/cheat/cheat.zsh"
	$0 "$@"
}

# Use exa as ls if exa is installed
if hash exa 2>/dev/null; then
	alias ls='exa'
	alias l='exa -l --all --group-directories-first --git'
	alias ll='exa -l --all --all --group-directories-first --git'
	alias lt='exa -T --git-ignore --level=2 --group-directories-first'
	alias llt='exa -lT --git-ignore --level=2 --group-directories-first'
	alias lT='exa -T --git-ignore --level=4 --group-directories-first'
fi

# Enable mcfly
export MCFLY_KEY_SCHEME=vim
export MCFLY_FUZZY=2
export MCFLY_HISTORY_LIMIT=10000
eval "$(mcfly init zsh)"