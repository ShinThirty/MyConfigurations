#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

setup_symlink() {
  local original="$1"
  local link="$2"
  mkdir -p "$(dirname "$link")"
  local short_link="${link/#$HOME/~}"
  if [ -L "$link" ] && [ -e "$link" ]; then
    echo -e "  \033[33m[skip]\033[0m $short_link"
  else
    rm -rf "$link"
    ln -sf "$original" "$link"
    echo -e "  \033[32m[link]\033[0m $short_link"
  fi
}

setup_symlinks_from_map() {
  local map_file="$1"
  while IFS=: read -r source target; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    source=$(eval echo "$source")
    target=$(eval echo "$target")
    setup_symlink "$source" "$target"
  done < "$map_file"
}

setup_symlinks_from_map "$DOTFILES/symlinks"

case "$OSTYPE" in
  darwin*)
    if [ -f "$DOTFILES/symlinks.darwin" ]; then
      echo "Setting up symlinks for macOS"
      setup_symlinks_from_map "$DOTFILES/symlinks.darwin"
    fi
    ;;
  linux*)
    if [ -f "$DOTFILES/symlinks.linux" ]; then
      echo "Setting up symlinks for Linux"
      setup_symlinks_from_map "$DOTFILES/symlinks.linux"
    fi
    ;;
  *) echo "unknown: $OSTYPE" ;;
esac
