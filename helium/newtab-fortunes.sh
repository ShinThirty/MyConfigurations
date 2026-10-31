#!/usr/bin/env bash
#
# Writes fortunes.js, next to links.js in ~/.config/helium-newtab, from the
# fortune database, for newtab.html to show one at random, the way `fortune |
# cowthink` would. It takes the files plain `fortune` reads, so none of the
# offensive ones, and from them the fortunes of 160 characters or fewer, the
# ones `fortune -s` picks. Without the file the page shows none. The database
# rarely changes, so run it once on each machine; Windows has no fortune.
#
set -euo pipefail

out="$HOME/.config/helium-newtab/fortunes.js"

# fortune -f lists what it reads: the directory, then each file in it
listing="$(fortune -f 2>&1)"
dir="$(awk 'NR == 1 { print $2 }' <<<"$listing")"
files=()
while read -r _ name; do
  files+=("$dir/$name")
done < <(tail -n +2 <<<"$listing")

# A fortune ends at a line of just %. Backspaces overstrike, for bold or
# underline: a word after as many underscores and then backspaces, or a
# character after another and a backspace. Keep only what's on top.
fortunes="$(
  for file in "${files[@]}"; do
    jq -Rs '. + "\n" | gsub("_+\b+"; "") | gsub("[^\b]\b"; "")
      | split("\n%\n") | .[] | gsub("^\n+|\n+$"; "")' "$file"
  done | jq -s -c 'map(select(length > 0 and length <= 160))'
)"

mkdir -p "${out%/*}"
tmp="$(mktemp "$out.XXXXXX")"
printf '// Written by MyConfigurations/helium/newtab-fortunes.sh\nconst fortunes = %s\n' \
  "$fortunes" >"$tmp"
mv "$tmp" "$out"
echo "Wrote $(jq length <<<"$fortunes") fortunes from ${#files[@]} files to ${out/#$HOME/~}"
