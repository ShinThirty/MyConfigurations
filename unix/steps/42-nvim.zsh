# nvim's plugins (lazy.nvim), and the tools and LSP servers mason installs. The
# treesitter parsers are left to the nvim config's auto-update, which rebuilds
# the ones whose pinned revision moved the next time nvim starts

update() {
  info 'nvim plugins'
  (( $+commands[nvim] )) || { skip 'nvim not installed'; return }
  # The bang and the Sync commands block until they finish, which a headless nvim
  # needs. nvim exits 0 even when a command fails, so failures are read from
  # what it prints: lazy prints its errors in red
  local lock=${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json out line moved=()
  local before=(${(f)"$(cat $lock 2>/dev/null)"})
  out=$(nvim --headless '+Lazy! sync' +qa 2>&1)
  local errors=(${(M)${(f)out}:#*$'\e[31m'*})
  local after=(${(f)"$(cat $lock 2>/dev/null)"})
  # Without the commas, a plugin that becomes or stops being the last doesn't count
  before=(${before%,}) after=(${after%,})
  for line in ${after:|before}; do moved+=(${${line#*\"}%%\"*}); done
  if (( $#errors )); then
    print -rl -- $errors | sed 's/^/  /'
    todo+=('nvim: Lazy! sync failed for the plugins above')
  fi
  if (( $#moved )); then ok "updated $moved"; elif (( ! $#errors )); then ok 'plugins up to date'; fi

  info 'nvim tools and LSP servers'
  # In a second nvim, so it runs the plugin code the first one just updated. It
  # prints nothing when all goes well
  out=$(nvim --headless '+MasonToolsUpdateSync' +qa 2>&1)
  if [[ -n $out ]]; then
    print -r -- $out | sed 's/^/  /'
    todo+=('nvim: read what MasonToolsUpdateSync printed above')
  fi
  # Anything mason installed that's still behind, whether it failed or isn't on
  # mason-tool-installer's list
  local check='local r = require("mason-registry"); local done = false
    r.refresh(function() done = true end); vim.wait(60000, function() return done end)
    for _, p in ipairs(r.get_installed_packages()) do
      if p:get_installed_version() ~= p:get_latest_version() then io.write(p.name, "\n") end
    end'
  local stale=(${(f)"$(nvim --headless -c "lua ${check//$'\n'/ }" +qa 2>/dev/null)"})
  if (( $#stale )); then
    todo+=("nvim: mason has newer versions of $stale (:Mason, then U)")
  else
    ok 'mason tools and LSP servers up to date'
  fi
}
