#!/usr/bin/env bash

set -euo pipefail

echo "Setting up symlinks with PWD = $PWD"

originals=(
	"$PWD/cheat"
	"$PWD/git/gitconfig"
	"$PWD/git/ignore"
	"$PWD/ideavim/ideavimrc"
	"$PWD/nano"
	"$PWD/nvim"
	"$PWD/p10k.zsh"
	"$PWD/tmux/tmux.conf"
	"$PWD/wezterm/wezterm.lua"
	"$PWD/zsh/zshrc"
)
links=(
	"$HOME/.config/cheat"
	"$HOME/.gitconfig"
	"$HOME/.config/git/ignore"
	"$HOME/.ideavimrc"
	"$HOME/.config/nano"
	"$HOME/.config/nvim"
	"$HOME/.p10k.zsh"
	"$HOME/.tmux.conf"
	"$HOME/.wezterm.lua"
	"$HOME/.zshrc"
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

setup_symlink_darwin() {
	echo "Setting up symlinks for MacOS"
	originals_darwin=(
		"$PWD/amethyst/amethyst.yml"
	)
	links_darwin=(
		"$HOME/.amethyst.yml"
	)

	for index in ${!originals_darwin[*]}; do
		original=${originals_darwin[$index]}
		link=${links_darwin[$index]}
		echo "Setting up symlink: $original -> $link"
		if [ -L "$link" ] && [ -e "$link" ]; then
			echo "Found existing $link"
		else
			rm -rf "$link"
			ln -sf "$original" "$link"
			echo "Created symlink: $original -> $link"
		fi
	done
}

case "$OSTYPE" in
darwin*) setup_symlink_darwin ;;
*) echo "unknown: $OSTYPE" ;;
esac
