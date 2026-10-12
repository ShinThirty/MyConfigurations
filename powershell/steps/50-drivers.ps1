# Drivers and the BIOS, yours to update since section 5.4 keeps them out of Windows Update, and the
# driver packages each new driver leaves behind. The cleanup deletes the packages you approve from
# one elevated window, by starting this file as admin with -Remove: run that way, it deletes them and
# writes the result file instead of returning its blocks.
param(
    # The approved packages, as oem1.inf,oem2.inf
    [ValidatePattern('^oem\d+\.inf(,oem\d+\.inf)*$')][string]$Remove
)

$step = @{
    Update = {
        Write-Step 'Drivers and BIOS'
        $bios = Get-CimInstance Win32_BIOS
        Write-Host "  BIOS $($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate.ToString('yyyy-MM-dd')))"
        Get-CimInstance Win32_PnPSignedDriver |
            Where-Object DeviceName -match 'NVIDIA GeForce|RZ717|Radeon|AMD PSP|Killer|U\.are\.U' |
            Sort-Object DeviceName |
            Format-Table DeviceName, DriverVersion, @{ n = 'Date'; e = { $_.DriverDate.ToString('yyyy-MM-dd') } } -AutoSize |
            Out-Host
        $todo.Add('Drivers and BIOS: check the versions above against the vendors (section 3.2)')
    }

    Cleanup = {
        param([string]$Remove)
        $goneDays = 30
        # Vendor installers put these back with every install, for hardware this PC doesn't have
        $keep = 'nvpcf.inf', 'nvppc.inf', 'smbusamd.inf'
        $resultFile = "$env:LOCALAPPDATA\monthly-update\cleanup-result.json"

        # Third-party driver packages, each with every device bound to it, plugged in or not
        function Get-DriverPackage {
            [xml]$drivers = pnputil /enum-drivers /devices /format xml
            [xml]$gone = pnputil /enum-devices /disconnected /drivers /format xml
            $unplugged = @{}
            foreach ($d in $gone.PnpUtil.Device) { $unplugged[$d.InstanceId] = $d.DriverName }
            foreach ($p in $drivers.PnpUtil.Driver) {
                # Unplugged devices too, in case /enum-drivers leaves them out
                $ids = @($p.Devices.Device | ForEach-Object InstanceId) + @($unplugged.Keys | Where-Object { $unplugged[$_] -eq $p.DriverName })
                [pscustomobject]@{
                    Inf = $p.DriverName; Original = $p.OriginalName; Class = $p.ClassName
                    Provider = $p.ProviderName; Version = $p.DriverVersion
                    Devices = @($ids | Sort-Object -Unique | ForEach-Object { [pscustomobject]@{ Id = $_; Plugged = -not $unplugged.ContainsKey($_) } })
                }
            }
        }

        if ($Remove) {
            # The elevated half. Bindings are read again, so a device plugged in since the prompt keeps
            # its driver
            $packages = Get-DriverPackage
            $results = foreach ($inf in $Remove -split ',') {
                $p = $packages | Where-Object Inf -eq $inf
                Write-Host "`n$inf ($($p.Original))" -ForegroundColor Cyan
                $result = [pscustomobject]@{ Inf = $inf; Original = $p.Original; Ok = $false; Message = '' }
                if (-not $p) { $result.Message = 'no longer in the driver store' }
                elseif ($p.Devices | Where-Object Plugged) { $result.Message = 'a device plugged in now uses it' }
                else {
                    # The unplugged devices' entries hold the package, as the Logitech receiver's did
                    foreach ($d in $p.Devices) { pnputil /remove-device $d.Id | Out-Host }
                    $out = pnputil /delete-driver $inf
                    $result.Ok = $LASTEXITCODE -eq 0
                    $out | Out-Host
                    $result.Message = $out | Where-Object { $_ -and $_ -ne 'Microsoft PnP Utility' } | Select-Object -Last 1
                }
                $result
            }
            New-Item -ItemType Directory -Force (Split-Path $resultFile) | Out-Null
            ConvertTo-Json -InputObject @($results) | Set-Content $resultFile
            return
        }

        function Get-LastSeen($id) {
            (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_LastRemovalDate, DEVPKEY_Device_LastArrivalDate -ErrorAction SilentlyContinue).Data |
                Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
        }

        Write-Step 'Cleanup: driver packages'
        # Printer drivers serve print queues, which pnputil doesn't count as devices: prnms009.inf
        # looks unused but is Microsoft Print to PDF
        $packages = @(Get-DriverPackage | Where-Object { $_.Class -ne 'Printer' -and $_.Original -notin $keep })
        $approved = [System.Collections.Generic.List[string]]::new()
        $unused = @($packages | Where-Object { -not $_.Devices })
        if ($unused) {
            Write-Host '  No device uses these:'
            $unused | ForEach-Object { Write-Host ('    {0,-10} {1,-24} {2,-17} {3,-28} {4}' -f $_.Inf, $_.Original, $_.Class, $_.Version, $_.Provider) }
            if ((Read-Host "  Delete $(($unused.Count -eq 1) ? 'it' : "all $($unused.Count)")? [y/N]") -eq 'y') { $unused | ForEach-Object { $approved.Add($_.Inf) } }
        }
        $offered = $unused.Count
        foreach ($p in $packages | Where-Object { $_.Devices -and -not ($_.Devices | Where-Object Plugged) }) {
            $seen = $p.Devices | ForEach-Object { Get-LastSeen $_.Id } | Sort-Object -Descending | Select-Object -First 1
            if (-not $seen -or $seen -gt (Get-Date).AddDays(-$goneDays)) { continue }
            $offered++
            Write-Host "  Only unplugged devices use $($p.Inf) ($($p.Original), $($p.Provider)): $($p.Devices.Count), last seen $($seen.ToString('yyyy-MM-dd'))"
            if ((Read-Host '  Remove their device entries, then the package? [y/N]') -eq 'y') { $approved.Add($p.Inf) }
        }
        if (-not $offered) { Write-Skip 'nothing to delete' }
        if (-not $approved) { return }

        Remove-Item $resultFile -ErrorAction SilentlyContinue
        try {
            Start-Process (Get-Process -Id $PID).Path -Verb RunAs -Wait -ErrorAction Stop `
                -ArgumentList '-NoProfile', '-File', "`"$StepFile`"", '-Remove', ($approved -join ',')
        } catch {
            $todo.Add('Driver packages: the UAC prompt was declined, so none were deleted. Run powershell\cleanup.ps1 to try again')
            return
        }
        if (-not (Test-Path $resultFile)) {
            $todo.Add('Driver packages: the elevated window closed without reporting back. pnputil /enum-drivers shows what is left')
            return
        }
        foreach ($r in Get-Content $resultFile -Raw | ConvertFrom-Json) {
            if ($r.Ok) { Write-Ok "deleted $($r.Inf) ($($r.Original))" }
            else { $todo.Add("Driver package $($r.Inf) ($($r.Original)) wasn't deleted: $($r.Message)") }
        }
        Remove-Item $resultFile
    }
}

if ($Remove) { & $step.Cleanup $Remove } else { $step }
