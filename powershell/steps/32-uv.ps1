# uv's own Pythons, the tools it installed, and its cache, which lives on D: (section 12.1)

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

        Write-Step 'uv-managed Pythons'
        # The installs themselves; each minor version's link beside them is a junction
        $pythons = @(Get-ChildItem (uv python dir) -Directory -ErrorAction SilentlyContinue | Where-Object { -not $_.LinkType -and $_.Name -notlike '.*' })
        if ($pythons) {
            # Venvs point at the minor-version junction, so they pick up the new patch release. The
            # cleanup uninstalls the one it replaces
            uv python upgrade
            if ($LASTEXITCODE) { $todo.Add('uv python upgrade failed: read its output above') }
        } else {
            Write-Skip 'none installed'
        }

        Write-Step 'uv tools'
        if (-not (Get-ChildItem (uv tool dir) -Directory -ErrorAction SilentlyContinue)) { Write-Skip 'none installed'; return }
        # Within the version constraints each was installed with
        uv tool upgrade --all
        if ($LASTEXITCODE) { $todo.Add('uv tool upgrade failed: read its output above') }
    }

    Cleanup = {
        Write-Step 'Cleanup: superseded uv Pythons'
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Write-Skip 'uv not installed'; return }
        # uv python upgrade installs the new patch release beside the old one and moves the
        # minor-version junction that venvs point at. The old one stays only for a venv made against
        # it directly, which would break without it.
        $pydir = uv python dir
        # cpython-3.13.16-windows-x86_64-none: the series is everything but the patch number. Sorted
        # with the numbers compared as numbers, so the last one in each series is the newest
        $re = '^([a-z]+-[0-9]+\.[0-9]+)\.[0-9a-z]+(.*)$'
        $pythons = @(Get-ChildItem $pydir -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not $_.LinkType -and $_.Name -match $re } |
            Sort-Object { [regex]::Replace($_.Name, '\d+', { $args[0].Value.PadLeft(10, '0') }) } |
            ForEach-Object Name)
        $newest = @{}
        foreach ($name in $pythons) { if ($name -match $re) { $newest[$Matches[1] + $Matches[2]] = $name } }
        $old = @($pythons | Where-Object { $_ -match $re -and $newest[$Matches[1] + $Matches[2]] -ne $_ })
        # The venvs in your home folder and on D:, where the projects are. Junctions aren't followed,
        # so nothing is visited twice. Not those inside uv's Pythons, or in its cache, wherever its
        # junction leads: the environments there are uv's own, made on demand, and the prune below
        # removes the ones left behind
        $venvs = @()
        if ($old) {
            $cache = uv cache dir
            $skip = @($pydir, $cache, (Get-Item $cache -ErrorAction SilentlyContinue).Target) |
                Where-Object { $_ } | ForEach-Object { "$($_.TrimEnd('\'))\" }
            $options = [IO.EnumerationOptions]@{ RecurseSubdirectories = $true; IgnoreInaccessible = $true; AttributesToSkip = 'ReparsePoint' }
            $venvs = @($HOME, 'D:\') | Where-Object { Test-Path $_ } |
                ForEach-Object { [IO.Directory]::EnumerateFiles($_, 'pyvenv.cfg', $options) } |
                Where-Object { $f = $_; -not ($skip | Where-Object { $f.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }) }
        }
        $remove = [System.Collections.Generic.List[string]]::new()
        foreach ($name in $old) {
            # A venv's pyvenv.cfg names the Python it was made against: its folder, or a file in it
            $made = '(?im)' + [regex]::Escape("$pydir\$name") + '(\\|\s*$)'
            $users = @($venvs | Where-Object { (Get-Content -LiteralPath $_ -Raw -ErrorAction SilentlyContinue) -match $made })
            if ($users) {
                $todo.Add("$name stays for the venvs made against it; recreate them to move them onto the minor-version junction: $(($users | Split-Path) -join ', ')")
            } else {
                $remove.Add($name)
            }
        }
        if ($remove.Count) {
            # uv reports on stderr. Captured, so a failure's cause makes it into the summary
            $out = @(uv python uninstall @remove 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
            $out | ForEach-Object { Write-Host "  $_" }
            if ($LASTEXITCODE) { $todo.Add("uv python uninstall failed: $($out[-1].Trim())") }
        } else {
            Write-Skip 'none'
        }

        Write-Step 'Cleanup: uv cache'
        # uv reports on stderr. Captured, so a failure's cause makes it into the summary
        $out = @(uv cache prune 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
        $out | ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE) { $todo.Add("uv cache prune failed: $($out[-1].Trim())") }
    }
}
