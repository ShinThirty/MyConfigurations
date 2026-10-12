#!/bin/bash

echo "Start updating BitTorrent tracker list at $(date)"

# 1. Define variables
tracker_url="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt"
# launchd and systemd start this without XDG_CONFIG_HOME, which only an
# interactive zsh exports
conf_file="${XDG_CONFIG_HOME:-$HOME/.config}/aria2/aria2.conf"

# 2. Download and format the list (replace newlines with commas). A failed
# download comes out empty, which would replace the working list with none.
tracker_list=$(curl -fsS "$tracker_url" | awk 'NF' | tr '\n' ',' | sed 's/,$//')
if [[ -z "$tracker_list" ]]; then
	echo "Couldn't download the tracker list, so aria2.conf keeps its old one." >&2
	exit 1
fi

# 3. Remove existing bt-tracker line and append the new one
if [[ "$OSTYPE" == "darwin"* ]]; then
	# macOS requires an empty string argument for sed -i
	sed -i '' '/^bt-tracker=/d' "$conf_file"
else
	# Linux (Arch) standard sed
	sed -i '/^bt-tracker=/d' "$conf_file"
fi

# 4. Add the new list to the config
echo "bt-tracker=$tracker_list" >>"$conf_file"

# 5. Restart aria2 to apply changes
if [[ "$OSTYPE" == "darwin"* ]]; then
	launchctl kickstart -k gui/"$(id -u)"/com.aria2
	echo "Trackers updated and aria2 restarted (macOS)."
else
	systemctl --user restart aria2.service
	echo "Trackers updated and aria2 restarted (Arch)."
fi
