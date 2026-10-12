# PowerShell modules, from the PowerShell Gallery

@{
    Update = {
        Write-Step 'PowerShell modules'
        Update-PSResource -TrustRepository
    }

    Cleanup = {
        Write-Step 'Cleanup: old PowerShell module versions'
        # Update-PSResource installs new versions beside the old. One loaded in this session has its
        # files open, so it waits for next month
        $loaded = Get-Module | ForEach-Object { "$($_.Name) $($_.Version)" }
        $old = @(Get-InstalledPSResource | Group-Object Name | ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -Skip 1 })
        foreach ($m in $old) {
            if ("$($m.Name) $($m.Version)" -in $loaded) { Write-Skip "kept $($m.Name) $($m.Version), loaded in this session"; continue }
            try {
                $m | Uninstall-PSResource -ErrorAction Stop
                Write-Host "  Removed $($m.Name) $($m.Version)"
            } catch { $todo.Add("Old module $($m.Name) $($m.Version) wasn't removed: $($_.Exception.Message)") }
        }
        if (-not $old) { Write-Skip 'none' }
    }
}
