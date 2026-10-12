#!/bin/zsh
#
# cleanup.sh — monthly cleanup for Arch (MIGRATION.arch.md section 10): every
# step's cleanup, which update.sh runs last. Run it on its own to free the space
# sooner. What looks after itself (the pacman cache, paru's builds, the journal,
# temp dirs, Go's build cache) isn't here.

DOTFILES=${0:A:h:h}
source $DOTFILES/unix/runner.zsh

run_steps arch cleanup
left_for_you
