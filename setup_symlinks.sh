#!/usr/bin/env bash

set -euo pipefail

echo "Setting up symlinks with PWD = $PWD"

originals=(
	"$PWD/amethyst/amethyst.yml"
	"$PWD/cheat"
	"$PWD/git/gitconfig"
	"$PWD/tmux/tmux.conf"
	"$PWD/vim"
	"$PWD/vim/ideavimrc"
	"$PWD/vim/vimrc"
	"$PWD/wezterm/wezterm.lua"
)
links=(
	"$HOME/.amethyst.yml"
	"$HOME/.config/cheat"
	"$HOME/.gitconfig"
	"$HOME/.tmux.conf"
	"$HOME/.vim"
	"$HOME/.ideavimrc"
	"$HOME/.vimrc"
	"$HOME/.wezterm.lua"
)

for index in ${!originals[*]}; do
	original=${originals[$index]}
	link=${links[$index]}
	echo "Setting up symlink: $original -> $link"
	if [ -L "$link" ] && [ -e "$link" ]; then
		echo "Found existing $link"
	else
		rm -rf "$link"
		ln -sf "$original" "$link"
		echo "Created symlink: $original -> $link"
	fi
done
