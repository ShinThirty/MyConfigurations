#!/bin/bash

echo "Start updating BitTorrent tracker list at $(date)"

# 1. Define variables
tracker_url="https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt"
conf_file="$XDG_CONFIG_HOME/aria2/aria2.conf"

# 2. Download and format the list (replace newlines with commas)
tracker_list=$(curl -s "$tracker_url" | awk 'NF' | tr '\n' ',' | sed 's/,$//')

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
