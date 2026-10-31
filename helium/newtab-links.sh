#!/usr/bin/env zsh
#
# Lists changes to make to the new tab page's links, in links.js in
# ~/.config/helium-newtab, from Helium's history: sites opened on 4 or more
# days of the last 30 that no link goes to, and links not opened in the last
# 90 days. A link goes to a site with the same host, www. aside, and it's
# opened when a page at or under its address is. A day counts only with a
# visit Helium would count toward its own most visited tiles. It writes
# nothing; arch/steps/83-helium.zsh runs it in the monthly update.
#
# Sites in ignore, next to links.js, are never suggested, nor their
# subdomains: one a line, such as example.com, and # starts a comment. Helium
# locks its history while it runs, so this reads a copy.

often_days=4
recent_days=30
stale_days=90

dir=${XDG_CONFIG_HOME:-$HOME/.config}/helium-newtab
links_file=$dir/links.js
ignore_file=$dir/ignore
case $OSTYPE in
  linux*) history_db=${HELIUM_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/net.imput.helium/Default/History ;;
  *) print -u2 "No Helium history path for $OSTYPE yet"; exit 1 ;;
esac

if [[ ! -f $links_file ]]; then
  print "there's no ${(D)links_file}, so the page has no links: newtab.html's header has the format"
  exit 0
fi
[[ -f $history_db ]] || { print -u2 "no Helium history at ${(D)history_db}"; exit 1 }

tmp=$(mktemp -d) || exit 1
trap 'command rm -rf $tmp' EXIT
command cp $history_db $history_db-journal(N) $tmp/ || exit 1

# Chromium's visit times are microseconds since 1601
since() {
  print "(strftime('%s', 'now') - $(( $1 * 86400 )) + 11644473600) * 1000000"
}
query() {
  sqlite3 -batch -noheader -separator ' ' $tmp/History $1
}
# The queries below run in pipes, which would hide a history they can't read
query 'select consider_for_ntp_most_visited, last_visit_time from visits, urls limit 1' >/dev/null ||
  exit 1

# https://www.example.com/path?query → example.com/path
address() {
  local rest=${1#*://}
  local host=${${rest%%/*}:l} path=/${rest#*/}
  [[ $rest == */* ]] || path=/
  print -r -- ${host#www.}${path%%[?#]*}
}

# Each link's name and URL, from lines such as ['GitHub', 'https://github.com']
names=() urls=()
q="[\"']"
for line in ${(f)"$(command grep -oE "\[[[:space:]]*${q}[^\"']*${q}[[:space:]]*,[[:space:]]*${q}https?://[^\"']*${q}" $links_file)"}; do
  [[ $line =~ "^\[[[:space:]]*${q}([^\"']*)${q}[[:space:]]*,[[:space:]]*${q}([^\"']*)" ]] || continue
  names+=($match[1]) urls+=($match[2])
done
link_addresses=(${(f)"$(for url in $urls; do address $url; done)"})
link_hosts=(${link_addresses%%/*})

ignored=()
if [[ -f $ignore_file ]]; then
  for line in ${(f)"$(<$ignore_file)"}; do
    line=${${line%%\#*}//[[:space:]]/}
    [[ -n $line ]] && ignored+=(${line:l})
  done
fi

# Sites opened on enough days, most days first
missing=()
query "
  with visit as (
    select substr(u.url, instr(u.url, '://') + 3) as rest, v.visit_time / 86400000000 as day
    from visits v join urls u on u.id = v.url
    where v.consider_for_ntp_most_visited and v.visit_time > $(since $recent_days)
      and (u.url like 'http://%' or u.url like 'https://%'))
  select lower(case instr(rest, '/') when 0 then rest else substr(rest, 1, instr(rest, '/') - 1) end) as host,
    count(distinct day) as days
  from visit group by host having days >= $often_days order by days desc, host" |
  while read -r host days; do
    (( ${link_hosts[(Ie)${host#www.}]} )) && continue
    for site in $ignored; do
      [[ $host == $site || $host == *.$site ]] && continue 2
    done
    missing+=("$host ($days days)")
  done
(( $#missing )) &&
  print "no link to ${(j:, :)missing}, opened often in the last $recent_days days: add one to ${(D)links_file}, or the site to ${(D)ignore_file}"

# Links with no page at or under their address opened since
opened=(${(f)"$(query "select url from urls where last_visit_time > $(since $stale_days)" |
  while IFS= read -r url; do address $url; done)"})
stale=()
for (( i = 1; i <= $#urls; i++ )); do
  prefix=$link_addresses[i]
  under=(${(M)opened:#$prefix*})
  (( $#under )) || stale+=($names[i])
done
(( $#stale )) &&
  print "${(j:, :)stale} not opened in the last $stale_days days: drop from ${(D)links_file} what you no longer need"
exit 0
