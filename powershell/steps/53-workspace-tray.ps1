# The GlazeWM workspace number's tray icon (glazewm/README.md). Its exe is built on this machine, so a
# change to glazewm/workspace-tray.cs or its build script reaches it only through this step, which
# rebuilds it when the hash the exe carries isn't theirs.

@{
    Update = {
        Write-Step 'GlazeWM workspace tray'
        $build = "$repo\glazewm\build-workspace-tray.ps1"
        if (-not (Test-Path "$env:LOCALAPPDATA\workspace-tray\workspace-tray.exe")) { Write-Skip 'not built here'; return }
        if (-not (& $build -Check)) { Write-Ok 'built from the current source'; return }

        $out = @(& $build)
        if ($LASTEXITCODE) {
            $out | ForEach-Object { Write-Host "  $_" }
            $todo.Add('GlazeWM workspace tray: the rebuild failed (the compiler''s errors are above), so the old exe still runs: fix glazewm\workspace-tray.cs and rerun glazewm\build-workspace-tray.ps1')
        } else {
            Write-Ok 'rebuilt from the changed source'
        }
    }
}
