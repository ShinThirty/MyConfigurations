# scoop itself, its buckets and its apps

@{
    Update = {
        Write-Step 'scoop'
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Write-Skip 'scoop not installed'; return }
        $appsDir = "$HOME\scoop\apps"
        scoop update                                    # scoop itself and the buckets
        $outdated = @(scoop status -l | Where-Object 'Latest Version' | ForEach-Object Name)
        # This terminal runs on pwsh and Windows Terminal, so neither can be replaced from here
        $selfHosted = @($outdated | Where-Object { $_ -in 'pwsh', 'windows-terminal' })
        # Manifests that check is_admin refuse to install unelevated (windowsdesktop-runtime-9.0)
        $adminOnly = @($outdated | Where-Object { $_ -notin $selfHosted -and (scoop cat $_ | Select-String -Quiet 'is_admin') })
        $update = @($outdated | Where-Object { $_ -notin $selfHosted + $adminOnly })

        $processes = Get-Process | Where-Object Path
        $running = @($update | Where-Object { $app = $_; $processes | Where-Object Path -like "$appsDir\$app\*" })
        # aria2 runs headless from its logon task; update_trackers.ps1 restarts it the same way
        $restartAria2 = 'aria2' -in $running
        if ($restartAria2) {
            Stop-Process -Name aria2c
            $running = @($running | Where-Object { $_ -ne 'aria2' })
        }
        if ($running) {
            Write-Warn "Running, so scoop would skip them: $($running -join ', ')"
            Read-Host '  Quit them to update them now, then press Enter (just Enter skips them)' | Out-Null
        }
        if ($update) { scoop update @update }
        if ($restartAria2) {
            Start-ScheduledTask Aria2
            Write-Ok 'restarted aria2'
        }

        $left = @(scoop status -l | Where-Object 'Latest Version' | ForEach-Object Name)
        $leftSelf = @($left | Where-Object { $_ -in $selfHosted })
        $leftAdmin = @($left | Where-Object { $_ -in $adminOnly })
        $leftOther = @($left | Where-Object { $_ -notin $leftSelf + $leftAdmin })
        if ($leftSelf) { $todo.Add("Close every Windows Terminal and pwsh window, then from Win+R > powershell: scoop update $leftSelf") }
        if ($leftAdmin) { $todo.Add("From an elevated shell: scoop update $leftAdmin") }
        if ($leftOther) { $todo.Add("Still outdated, quit it first if it's running: scoop update $leftOther") }
    }

    Cleanup = {
        Write-Step 'Cleanup: old scoop versions and their downloads'
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Write-Skip 'scoop not installed'; return }
        scoop cleanup * --cache
    }
}
