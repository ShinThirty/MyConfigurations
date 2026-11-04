#!/usr/bin/env bash
#
# Starts KeePassXC at login on Arch with the main database from tp-share,
# which KeePassXC skips when the share isn't there, and the Login one, the
# Secret Service's (SECURITY.md section 7). Hyprland's
# UserConfigs/user_startup.lua runs this; arch/kooldots-upgrade.sh puts that
# entry back when KooL's upgrade drops it, and arch/steps/80-settings.zsh
# checks it. KeePassXC starts in the tray with both databases locked, as
# MinimizeOnStartup has it.
#
# Qt looks for a tray only once, at start, and finds one only once its host
# has registered with the watcher, which waybar does a moment after taking the
# watcher's name. So this waits for that, for up to 30 seconds, and KeePassXC
# starts without a tray after that.
#

for _ in {1..60}; do
  [[ "$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null)" == 'b true' ]] && break
  sleep 0.5
done

# Login opens last, so it's the active tab, whose database the Secret Service
# gives apps as the default for new secrets
exec keepassxc --minimized /mnt/tp-share/Password/shinthirty.kdbx "$HOME/.local/share/keepassxc/login.kdbx"
