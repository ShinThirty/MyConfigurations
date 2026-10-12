# macOS and Apple's other updates, listed here and installed from System Settings

update() {
  # Automatic updates are on, but they can sit offered for weeks. Installing one
  # takes your password and usually a restart, so that part stays in System Settings.
  info 'Software Update'
  local swu=$(softwareupdate --list 2>&1)
  local major=${$(sw_vers -productVersion)%%.*}
  local titles=(${(M)${(f)swu}:#*Title: *}) updates=() line title version
  for line in $titles; do
    title=${${line#*Title: }%%,*}
    version=${${line#*Version: }%%,*}
    if [[ $title == macOS* && ${version%%.*} != $major ]]; then
      skip "$title is a new major version, not part of the monthly update"
    else
      [[ $title == *$version* ]] || title+=" $version"     # Safari's title has none
      [[ $line == *'Action: restart'* ]] && title+=' (restarts)'
      updates+=($title)
    fi
  done
  if (( $#updates )); then
    printf '  %s\n' $updates
    open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension'
    print '  Opened System Settings → Software Update: install them there once this has finished'
    todo+=("Software Update: ${(j:, :)updates}")
  elif (( $#titles )) || [[ $swu == *'No new software available'* ]]; then
    ok "macOS $(sw_vers -productVersion) is up to date"
  else
    warn 'softwareupdate --list failed:'
    print -r -- $swu | sed 's/^/    /'
    todo+=('Software Update: check it in System Settings, softwareupdate --list failed')
  fi
}
