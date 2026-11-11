# nvim's plugins (lazy.nvim), and the tools and LSP servers mason installs. The treesitter parsers
# are left to the nvim config's auto-update, which rebuilds the ones whose pinned revision moved the
# next time nvim starts. Each nvim has a time limit, as one that hangs would hold up the whole update

@{
    Update = {
        Write-Step 'nvim plugins'
        if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) { Write-Skip 'nvim not installed'; return }
        # The bang and the Sync commands block until they finish, which a headless nvim needs. nvim
        # exits 0 even when a command fails, so failures are read from what it prints: lazy prints its
        # errors in red. Without the commas, a plugin that becomes or stops being the last doesn't count
        $lock = "$env:LOCALAPPDATA\nvim\lazy-lock.json"
        $before = @(Get-Content $lock -ErrorAction SilentlyContinue | ForEach-Object { $_.TrimEnd(',') })
        $out = @(Invoke-Capped 600 nvim '--headless', '+Lazy! sync', '+qa')
        $stopped = $LASTEXITCODE -eq 124
        $errors = @($out | Where-Object { $_.Contains("`e[31m") })
        $after = @(Get-Content $lock -ErrorAction SilentlyContinue | ForEach-Object { $_.TrimEnd(',') })
        $moved = @($after | Where-Object { $_ -cnotin $before } | ForEach-Object { ($_ -split '"')[1] } | Where-Object { $_ })
        if ($errors) {
            $errors | ForEach-Object { Write-Host "  $_" }
            $todo.Add('nvim: Lazy! sync failed for the plugins above')
        }
        if ($stopped) {
            Write-Warn 'Lazy! sync was stopped after 10 minutes'
            $todo.Add('nvim: Lazy! sync was stopped after 10 minutes: run :Lazy sync in nvim')
        }
        if ($moved) { Write-Ok "updated $moved" } elseif (-not $errors -and -not $stopped) { Write-Ok 'plugins up to date' }

        Write-Step 'nvim tools and LSP servers'
        # In a second nvim, so it runs the plugin code the first one just updated. It prints nothing
        # when all goes well
        $out = @(Invoke-Capped 600 nvim '--headless', '+MasonToolsUpdateSync', '+qa')
        if ($LASTEXITCODE -eq 124) {
            Write-Warn 'MasonToolsUpdateSync was stopped after 10 minutes'
            $todo.Add('nvim: MasonToolsUpdateSync was stopped after 10 minutes: run :MasonToolsUpdate in nvim')
        }
        $out = @($out | Where-Object { $_.Trim() })
        if ($out) {
            $out | ForEach-Object { Write-Host "  $_" }
            $todo.Add('nvim: read what MasonToolsUpdateSync printed above')
        }
        # Anything mason installed that's still behind, whether it failed or isn't on
        # mason-tool-installer's list. -c takes the Lua as one line
        $check = @'
local r = require('mason-registry'); local done = false
r.refresh(function() done = true end); vim.wait(60000, function() return done end)
for _, p in ipairs(r.get_installed_packages()) do
  if p:get_installed_version() ~= p:get_latest_version() then io.write(p.name, '\n') end
end
'@ -replace '\r?\n', ' '
        $stale = @(Invoke-Capped 120 nvim '--headless', '-c', "lua $check", '+qa' -NoStderr | Where-Object { $_.Trim() })
        if ($LASTEXITCODE -eq 124) {
            Write-Warn "mason's version check was stopped after 2 minutes"
            $todo.Add("nvim: mason's version check was stopped after 2 minutes: :Mason shows what's behind")
        } elseif ($stale) {
            $todo.Add("nvim: mason has newer versions of $stale (:Mason, then U)")
        } else {
            Write-Ok 'mason tools and LSP servers up to date'
        }
    }
}
