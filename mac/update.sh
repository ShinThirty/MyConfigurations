#!/bin/zsh
#
# update.sh — monthly update for macOS, attended (MIGRATION.md section 8).
#
# Runs every step's update, then every step's cleanup (unix/runner.zsh says
# where the steps are), and ends with what's left for you. Finishing records
# the run, which silences update-reminder.sh until the next Patch Tuesday.

[[ "$OSTYPE" == darwin* ]] || { print -u2 "update.sh is macOS-only (got $OSTYPE)"; exit 1 }

DOTFILES=${0:A:h:h}
source $DOTFILES/unix/runner.zsh

run_steps mac update cleanup
left_for_you

state=~/.local/state/monthly-update
mkdir -p $state
date +%F >$state/last-run
printf '\n\033[32m%s\033[0m\n' "Recorded this month's run; the reminder stays quiet until the next Patch Tuesday"
