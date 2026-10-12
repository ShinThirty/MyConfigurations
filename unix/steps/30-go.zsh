# The Go tools in the Brewfile's go lines, and the module cache go install fills

update() {
  info 'Go tools'
  (( $+commands[go] )) || { skip 'go not installed'; return }
  # go install @latest installs or upgrades each one, and rebuilds it with the
  # Go that the package manager just upgraded
  local tools=(${(f)"$(sed -n 's/^go "\(.*\)"$/\1/p' $DOTFILES/Brewfile)"}) tool failed=()
  for tool in $tools; do
    if go install $tool@latest; then ok ${tool:t}; else failed+=($tool); fi
  done
  (( $#failed )) && todo+=("go install failed for: $failed")

  # Matched by module path rather than name, since go install never removes
  # anything: these are left from earlier lists, and nothing updates them
  local gobin=$(go env GOBIN) bin mod extra=()
  [[ -n $gobin ]] || gobin=$(go env GOPATH)/bin
  for bin in $gobin/*(N); do
    mod=$(go version -m $bin 2>/dev/null | awk '$1 == "path" { print $2; exit }')
    (( ${tools[(Ie)$mod]} )) || extra+=(${bin:t})
  done
  (( $#extra )) &&
    todo+=("Go tools not in the Brewfile, so never updated — delete them from ${gobin/#$HOME/~} or add them: $extra")
}

cleanup() {
  # Go never prunes it, so it keeps every version ever downloaded, and each
  # month's go install @latest adds another set. Go projects download what they
  # need again on their next build.
  info 'Cleanup: Go module cache'
  local modcache=$(go env GOMODCACHE 2>/dev/null) kb
  if [[ ! -d $modcache ]]; then
    skip 'empty'
    return
  fi
  kb=$(du -sk $modcache | cut -f1)
  if go clean -modcache; then
    ok "removed $(( kb / 1024 )) MB from ${modcache/#$HOME/~}"
  else
    todo+=('go clean -modcache failed: read its output above')
  fi
}
