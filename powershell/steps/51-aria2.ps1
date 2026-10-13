# aria2's installed copies in ~\.config\aria2 (aria2/windows). install.ps1 copies them rather than
# links them, since the weekly task rewrites aria2.conf, so a change in the repo reaches this machine
# only through this step.

@{
    Update = {
        Write-Step 'aria2'
        $dir = "$HOME\.config\aria2"
        $conf = "$dir\aria2.conf"
        if (-not (Get-Command aria2c -ErrorAction SilentlyContinue) -or -not (Test-Path $conf)) { Write-Skip 'not set up here'; return }

        $changed = [System.Collections.Generic.List[string]]::new()
        foreach ($name in 'Start-Aria2.vbs', 'update_trackers.ps1', 'Update-Trackers.vbs') {
            $src = "$repo\aria2\windows\$name"
            if ((Get-FileHash $src).Hash -ne (Get-FileHash "$dir\$name" -ErrorAction SilentlyContinue).Hash) {
                Copy-Item $src $dir
                $changed.Add($name)
            }
        }

        # The installed aria2.conf has two lines of its own: dir= from install.ps1 -DownloadDir, and
        # the bt-tracker= the weekly task writes, which the repo's lacks. The rest should match, so
        # it's rewritten from the repo's with those two kept.
        $own = '^(dir|bt-tracker)='
        $repoConf = @(Get-Content "$repo\aria2\aria2.conf")
        $installed = @(Get-Content $conf)
        $want = ($repoConf -notmatch $own) -join "`n"
        $have = ($installed -notmatch $own) -join "`n"
        if ($want -ne $have) {
            $dirLine = @($installed -match '^dir=')[0]
            $merged = foreach ($line in ($repoConf -notmatch '^bt-tracker=')) {
                if ($dirLine -and $line -match '^dir=') { $dirLine } else { $line }
            }
            @($merged) + @($installed -match '^bt-tracker=') | Set-Content $conf
            $changed.Add('aria2.conf')
        }

        if ($changed.Count) { Write-Ok "updated from the repo: $($changed -join ', ')" } else { Write-Ok 'the installed copies match the repo' }

        $state = @{}
        foreach ($name in 'Aria2', 'Aria2 Update Trackers') {
            $state[$name] = (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue).State
            if ($null -eq $state[$name]) {
                # install.ps1 overwrites aria2.conf, trackers and all
                $todo.Add("aria2: the '$name' task is gone: rerun install.ps1 with your -DownloadDir (section 11), then Start-ScheduledTask 'Aria2 Update Trackers'")
            } elseif ($state[$name] -eq 'Disabled') {
                $todo.Add("aria2: the '$name' task is disabled: Enable-ScheduledTask '$name'")
            }
        }

        if (($changed -contains 'aria2.conf' -or $changed -contains 'Start-Aria2.vbs') -and
            $state['Aria2'] -notin $null, 'Disabled' -and (Get-Process aria2c -ErrorAction SilentlyContinue)) {
            Stop-Process -Name aria2c
            # The Aria2 task waits on aria2c, and won't start again until Task Scheduler sees it end
            $deadline = (Get-Date).AddSeconds(10)
            while ((Get-ScheduledTask Aria2).State -eq 'Running' -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
            Start-ScheduledTask Aria2
            Write-Ok 'restarted aria2'
        }
    }
}
