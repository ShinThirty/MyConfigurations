#!/bin/zsh
#
# cleanup.sh — monthly cleanup for macOS (MIGRATION.md section 8): every step's
# cleanup, which update.sh runs last. Run it on its own to free the space
# sooner. macOS clears its own temp folder and Go trims its build cache, so
# neither is here.

[[ "$OSTYPE" == darwin* ]] || { print -u2 "cleanup.sh is macOS-only (got $OSTYPE)"; exit 1 }

DOTFILES=${0:A:h:h}
source $DOTFILES/unix/runner.zsh

run_steps mac cleanup
left_for_you
