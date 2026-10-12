# Monthly cleanup (MIGRATION.windows.md section 15). update.ps1 runs it last; run it on its own after
# installing a vendor driver, to clear the version that one replaced. From pwsh, unelevated: it clears
# what needs no admin itself, then deletes the driver packages you approve from one elevated window.
param(
    # update.ps1's list of what's left for you; run on its own, the script prints its own
    [System.Collections.Generic.List[string]]$Todo,
    # The elevated half: the approved packages, as oem1.inf,oem2.inf
    [ValidatePattern('^oem\d+\.inf(,oem\d+\.inf)*$')][string]$Remove
)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Run this from pwsh (PowerShell 7), not Windows PowerShell" -ForegroundColor Red
    exit 1
}

$tempDays = 7
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

function Get-LastSeen($id) {
    (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_LastRemovalDate, DEVPKEY_Device_LastArrivalDate -ErrorAction SilentlyContinue).Data |
        Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
}

if ($Remove) {
    # Bindings are read again, so a device plugged in since the prompt keeps its driver
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

$standalone = -not $PSBoundParameters.ContainsKey('Todo')
if ($standalone) { $Todo = [System.Collections.Generic.List[string]]::new() }
function Write-Step($title) { Write-Host "`n== $title" -ForegroundColor Cyan }

Write-Step 'Cleanup: old PowerShell module versions'
# Update-PSResource installs new versions beside the old. One loaded in this session has its files
# open, so it waits for next month
$loaded = Get-Module | ForEach-Object { "$($_.Name) $($_.Version)" }
$old = @(Get-InstalledPSResource | Group-Object Name | ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -Skip 1 })
foreach ($m in $old) {
    if ("$($m.Name) $($m.Version)" -in $loaded) { Write-Host "  Kept $($m.Name) $($m.Version), loaded in this session"; continue }
    try {
        $m | Uninstall-PSResource -ErrorAction Stop
        Write-Host "  Removed $($m.Name) $($m.Version)"
    } catch { $Todo.Add("Old module $($m.Name) $($m.Version) wasn't removed: $($_.Exception.Message)") }
}
if (-not $old) { Write-Host '  None' }

Write-Step 'Cleanup: uv cache'
# uv reports on stderr. Captured, so a failure's cause makes it into the summary
$out = @(uv cache prune 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
$out | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE) { $Todo.Add("uv cache prune failed: $($out[-1].Trim())") }

Write-Step "Cleanup: TEMP files older than $tempDays days"
$cutoff = (Get-Date).AddDays(-$tempDays)
$count = 0; $bytes = 0; $inUse = 0
# pwsh doesn't recurse into links, so a junction in TEMP can't lead this anywhere else
Get-ChildItem $env:TEMP -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff | ForEach-Object {
    $size = $_.Length
    try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; $count++; $bytes += $size } catch { $inUse++ }
}
# Then the folders that leaves empty, deepest first. By creation date, since deleting a folder's files
# moves its modified date. Directory.Delete refuses a folder that isn't empty, where Remove-Item would
# ask to delete its contents
Get-ChildItem $env:TEMP -Recurse -Force -Directory -Attributes !ReparsePoint -ErrorAction SilentlyContinue |
    Where-Object CreationTime -lt $cutoff | Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object { try { [IO.Directory]::Delete($_.FullName) } catch {} }
Write-Host ('  Deleted {0} files, {1:N0} MB' -f $count, ($bytes / 1MB))
if ($inUse) { Write-Host "  $inUse in use, so left for next month" }

Write-Step 'Cleanup: driver packages'
# Printer drivers serve print queues, which pnputil doesn't count as devices: prnms009.inf looks
# unused but is Microsoft Print to PDF
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
if (-not $offered) { Write-Host '  Nothing to delete' }

if ($approved) {
    Remove-Item $resultFile -ErrorAction SilentlyContinue
    $elevated = $true
    try {
        Start-Process (Get-Process -Id $PID).Path -Verb RunAs -Wait -ErrorAction Stop `
            -ArgumentList '-NoProfile', '-File', "`"$PSCommandPath`"", '-Remove', ($approved -join ',')
    } catch {
        $elevated = $false
        $Todo.Add('Driver packages: the UAC prompt was declined, so none were deleted. Run powershell\cleanup.ps1 to try again')
    }
    if ($elevated -and (Test-Path $resultFile)) {
        foreach ($r in Get-Content $resultFile -Raw | ConvertFrom-Json) {
            if ($r.Ok) { Write-Host "  Deleted $($r.Inf) ($($r.Original))" }
            else { $Todo.Add("Driver package $($r.Inf) ($($r.Original)) wasn't deleted: $($r.Message)") }
        }
        Remove-Item $resultFile
    } elseif ($elevated) {
        $Todo.Add('Driver packages: the elevated window closed without reporting back. pnputil /enum-drivers shows what is left')
    }
}

if ($standalone -and $Todo) {
    Write-Step 'Left for you'
    $Todo | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
