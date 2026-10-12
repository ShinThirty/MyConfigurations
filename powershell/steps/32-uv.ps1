# uv's cache, which lives on D: (section 12.1). uv has no Pythons of its own here, so there's no
# uv python upgrade as on macOS and Arch

@{
    Update = {
        Write-Step 'uv cache'
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Write-Skip 'uv not installed'; return }
        # scoop's uv manifest resets UV_CACHE_DIR on every update; the junction keeps the cache on D:
        if ((Get-Item "$HOME\scoop\persist\uv\cache" -ErrorAction SilentlyContinue).LinkType -eq 'Junction') {
            Write-Ok 'still on D:'
        } else {
            Write-Warn 'no longer on D:'
            $todo.Add('uv: ~\scoop\persist\uv\cache is no longer a junction to D:\uv-cache (section 12.1)')
        }
    }

    Cleanup = {
        Write-Step 'Cleanup: uv cache'
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Write-Skip 'uv not installed'; return }
        # uv reports on stderr. Captured, so a failure's cause makes it into the summary
        $out = @(uv cache prune 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
        $out | ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE) { $todo.Add("uv cache prune failed: $($out[-1].Trim())") }
    }
}
