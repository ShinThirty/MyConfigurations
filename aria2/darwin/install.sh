#!/bin/bash

# Create the aria2 configuration directory
echo "Creating directory: $XDG_CONFIG_HOME/aria2"
mkdir -p "$XDG_CONFIG_HOME/aria2"

# Copy the aria2 configuration file, readable only by you, with its RPC
# secret: the one a previous install made, or a new one (SECURITY.md section 6)
secret=$(grep '^rpc-secret=' "$XDG_CONFIG_HOME/aria2/aria2.conf" 2>/dev/null)
echo "Copying aria2.conf to: $XDG_CONFIG_HOME/aria2/aria2.conf"
cp ../aria2.conf "$XDG_CONFIG_HOME/aria2/aria2.conf"
chmod 600 "$XDG_CONFIG_HOME/aria2/aria2.conf"
echo "${secret:-rpc-secret=$(openssl rand -hex 16)}" >>"$XDG_CONFIG_HOME/aria2/aria2.conf"
echo "Copying aria2_update_tracker.sh to: $XDG_CONFIG_HOME/aria2/aria2_update_tracker.sh"
cp ../aria2_update_tracker.sh "$XDG_CONFIG_HOME/aria2/aria2_update_tracker.sh"

# Create the aria2 session file
echo "Creating empty session file: $XDG_CONFIG_HOME/aria2/aria2.session"
touch "$XDG_CONFIG_HOME/aria2/aria2.session"

echo "Copying com.aria2.plist to $HOME/Library/LaunchAgents/com.aria2.plist"
cp com.aria2.plist "$HOME/Library/LaunchAgents/com.aria2.plist"
echo "Copying com.aria2.regular.tracker.update.plist to $HOME/Library/LaunchAgents/com.aria2.regular.tracker.update.plist"
cp com.aria2.regular.tracker.update.plist "$HOME/Library/LaunchAgents/com.aria2.regular.tracker.update.plist"

cat <<EOF

Setup complete. Use the following command to start aria2 on user login:

launchctl load ~/Library/LaunchAgents/com.aria2.plist
launchctl load ~/Library/LaunchAgents/com.aria2.regular.tracker.update.plist

To allow incoming connections from BitTorrent peers, it is recommended to setup on-router port-forwarding rules and firewall rules.

Aria2 Explorer and AriaNg need the RPC secret, the rpc-secret= line in $XDG_CONFIG_HOME/aria2/aria2.conf.
EOF
