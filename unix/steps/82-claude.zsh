# Claude Code's own update checks, kept off. The package manager updates it
# (the claude-code@latest cask on macOS, the AUR on Arch), and DISABLE_AUTOUPDATER
# in its settings.json leaves that to 20. This puts the key back when a restored
# or rewritten settings.json has lost it.

update() {
  info 'Claude Code'
  (( $+commands[claude] )) || { skip 'not installed'; return }
  local settings=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json fixed
  local shown=${settings/#$HOME/\~}
  # With no settings.json yet, jq -n starts from null, which the assignment
  # below turns into an object
  local from=(-n)
  [[ -s $settings ]] && from=($settings)
  if jq -e '.env.DISABLE_AUTOUPDATER == "1"' $from &>/dev/null; then
    ok 'its own update checks are off'
  elif fixed=$(jq '.env.DISABLE_AUTOUPDATER = "1"' $from 2>/dev/null); then
    mkdir -p ${settings:h} && print -r -- $fixed >$settings &&
      ok "turned its own update checks back off in $shown"
  else
    warn "$shown isn't valid JSON"
    todo+=("Claude Code: fix $shown, then rerun the update to turn its own update checks back off")
  fi
}
