#!/bin/bash

# Create the aria2 configuration directory
echo "Creating directory: $XDG_CONFIG_HOME/aria2"
mkdir -p "$XDG_CONFIG_HOME/aria2"

# Copy the aria2 configuration file
echo "Copying aria2.conf to: $XDG_CONFIG_HOME/aria2/aria2.conf"
cp ../aria2.conf "$XDG_CONFIG_HOME/aria2/aria2.conf"
echo "Copying aria2_update_tracker.sh to: $XDG_CONFIG_HOME/aria2/aria2_update_tracker.sh"
cp ../aria2_update_tracker.sh "$XDG_CONFIG_HOME/aria2/aria2_update_tracker.sh"

# Create the aria2 session file
echo "Creating empty session file: $XDG_CONFIG_HOME/aria2/aria2.session"
touch "$XDG_CONFIG_HOME/aria2/aria2.session"

# Create the user systemd directory
echo "Creating directory: $XDG_CONFIG_HOME/systemd/user"
mkdir -p "$XDG_CONFIG_HOME/systemd/user"

# Copy the aria2 systemd service file
echo "Copying aria2.service to: $XDG_CONFIG_HOME/systemd/user/aria2.service"
cp ./aria2.service "$XDG_CONFIG_HOME/systemd/user/aria2.service"
echo "Copying aria2_update_tracker.service to: $XDG_CONFIG_HOME/systemd/user/aria2_update_tracker.service"
cp ./aria2_update_tracker.service "$XDG_CONFIG_HOME/systemd/user/aria2_update_tracker.service"
echo "Copying aria2_update_tracker.timer to: $XDG_CONFIG_HOME/systemd/user/aria2_update_tracker.timer"
cp ./aria2_update_tracker.timer "$XDG_CONFIG_HOME/systemd/user/aria2_update_tracker.timer"

cat <<EOF

Setup complete. Enable aria2 service and update tracker timer by

systemctl --user enable aria2.service
systemctl --user start aria2.service
systemctl --user enable aria2_update_tracker.timer
systemctl --user start aria2_update_tracker.timer

To allow incoming connections from BitTorrent peers, it is recommended to setup on-router port-forwarding rules and firewall rules.
EOF
