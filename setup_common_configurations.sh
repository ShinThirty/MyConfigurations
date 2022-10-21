#!/usr/bin/env bash

set -euo pipefail

statement="# Common Definitions"
echo "Adding statement: $statement"
if rg -q "$statement" "$HOME/.zshrc"; then
	echo "Found existing $statement"
else
	echo >>"$HOME/.zshrc"
	echo "$statement" >>"$HOME/.zshrc"
fi

statements=(
	"alias rfv=\"$PWD/zsh/rfv\""
	"source \"$PWD/zsh/zshrc.common\""
	"source \"$PWD/fzf-git/fzf-git.sh\""
	"source \"$PWD/kubectl/kubectl.zsh\""
)

for index in ${!statements[*]}; do
	statement=${statements[$index]}
	echo "Adding statement: $statement"
	if rg -q "$statement" "$HOME/.zshrc"; then
		echo "Found existing $statement"
	else
		echo "$statement" >>"$HOME/.zshrc"
	fi
done
