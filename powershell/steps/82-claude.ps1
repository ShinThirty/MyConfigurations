# Claude Code's own update checks, kept off. scoop updates it (20-scoop), while its updater takes the
# scoop install for a native one and drops a second copy in ~\.local (section 12.1). DISABLE_AUTOUPDATER
# in its settings.json turns that off; this puts the key back when a restored or rewritten
# settings.json has lost it, and flags a copy the updater left before then.

@{
    Update = {
        Write-Step 'Claude Code'
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Skip 'not installed'; return }
        $settings = Join-Path ($env:CLAUDE_CONFIG_DIR ?? "$HOME\.claude") settings.json
        $shown = $settings.Replace($HOME, '~')
        # With no settings.json yet, jq -n starts from null, which the assignment below turns into an
        # object
        $from = (Get-Item $settings -ErrorAction SilentlyContinue).Length ? $settings : '-n'
        jq -e '.env.DISABLE_AUTOUPDATER == "1"' $from *> $null
        if (-not $LASTEXITCODE) {
            Write-Ok 'its own update checks are off'
        } else {
            # jq -a escapes everything outside ASCII, so the console's encoding can't garble what it writes
            $fixed = jq -a '.env.DISABLE_AUTOUPDATER = "1"' $from 2> $null
            if ($LASTEXITCODE) {
                Write-Warn "$shown isn't valid JSON"
                $todo.Add("Claude Code: fix $shown, then rerun the update to turn its own update checks back off")
            } else {
                New-Item -ItemType Directory -Force (Split-Path $settings) | Out-Null
                Set-Content -NoNewline $settings (($fixed -join "`n") + "`n")
                Write-Ok "turned its own update checks back off in $shown"
            }
        }
        $stray = "$HOME\.local\bin\claude.exe", "$HOME\.local\share\claude" | Where-Object { Test-Path $_ }
        if ($stray) {
            Write-Warn "its updater left a native copy beside scoop's"
            $todo.Add("Claude Code: delete $(($stray | ForEach-Object { $_.Replace($HOME, '~') }) -join ' and '), the native copy its own updater left beside scoop's (section 12.1)")
        }
    }
}
