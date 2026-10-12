#!/bin/zsh
#
# update.sh — monthly update for Arch, attended (MIGRATION.arch.md section 10).
# Run as your normal user.
#
# Covers what day-to-day `paru` runs don't: mirrors, merging .pacnew files, the
# toolchains and plugins outside pacman, and checks for what needs a reboot or a
# look. Runs every step's update, then every step's cleanup (unix/runner.zsh
# says where the steps are), and ends with what's left for you. Finishing
# records the run, which silences update-reminder.sh until the next due date.

(( EUID )) || { print -u2 'run this as your normal user, not root (it calls sudo where needed)'; exit 1 }

DOTFILES=${0:A:h:h}
source $DOTFILES/unix/runner.zsh

run_steps arch update cleanup
left_for_you

state=${XDG_STATE_HOME:-$HOME/.local/state}/monthly-update
mkdir -p $state
date +%F >$state/last-run
printf '\n\033[32m%s\033[0m\n' "Recorded this month's run; the reminder stays quiet until the next due date"
