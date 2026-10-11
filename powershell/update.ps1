# Monthly update, attended (MIGRATION.windows.md section 15). Run from pwsh, unelevated.
# Updates everything that can be updated from here, reports the driver and BIOS versions to
# check against the vendors, and ends with what's left for you. Finishing records the run,
# which silences update_reminder.ps1 until the next Patch Tuesday.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Run this from pwsh (PowerShell 7), not Windows PowerShell" -ForegroundColor Red
    exit 1
}

$repo = "$HOME\MyConfigurations"
$appsDir = "$HOME\scoop\apps"
$todo = [System.Collections.Generic.List[string]]::new()
function Write-Step($title) { Write-Host "`n== $title" -ForegroundColor Cyan }

Write-Step 'Windows Update'
# Drivers are excluded by policy (section 5.4), so this is the cumulative update, Defender and .NET
Start-Process 'ms-settings:windowsupdate'
Write-Host '  Opened Settings > Windows Update: check for updates there while this runs'

Write-Step 'scoop'
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
    Write-Host "  Running, so scoop would skip them: $($running -join ', ')" -ForegroundColor Yellow
    Read-Host '  Quit them to update them now, then press Enter (just Enter skips them)' | Out-Null
}
if ($update) { scoop update @update }
if ($restartAria2) { Start-ScheduledTask Aria2 }
scoop cleanup * --cache                         # old versions and their downloads

# scoop's uv manifest resets UV_CACHE_DIR on every update; the junction keeps the cache on D: (section 12.1)
if ((Get-Item "$HOME\scoop\persist\uv\cache" -ErrorAction SilentlyContinue).LinkType -ne 'Junction') {
    $todo.Add('uv: ~\scoop\persist\uv\cache is no longer a junction to D:\uv-cache (section 12.1)')
}

$left = @(scoop status -l | Where-Object 'Latest Version' | ForEach-Object Name)
$leftSelf = @($left | Where-Object { $_ -in $selfHosted })
$leftAdmin = @($left | Where-Object { $_ -in $adminOnly })
$leftOther = @($left | Where-Object { $_ -notin $leftSelf + $leftAdmin })
if ($leftSelf) { $todo.Add("Close every Windows Terminal and pwsh window, then from Win+R > powershell: scoop update $leftSelf") }
if ($leftAdmin) { $todo.Add("From an elevated shell: scoop update $leftAdmin") }
if ($leftOther) { $todo.Add("Still outdated, quit it first if it's running: scoop update $leftOther") }

Write-Step 'Rust toolchain'
rustup update

Write-Step 'PowerShell modules'
Update-PSResource -TrustRepository

Write-Step 'yazi packages'
ya pkg upgrade
if (git -C $repo status --porcelain -- yazi/package.toml) { $todo.Add('Commit the new yazi/package.toml revisions') }

$todo.Add('nvim: :Lazy update, then :MasonToolsUpdate and :TSUpdate!')

Write-Step 'Drivers and BIOS: check these against the vendors (section 3.2)'
$bios = Get-CimInstance Win32_BIOS
Write-Host "  BIOS $($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate.ToString('yyyy-MM-dd')))"
Get-CimInstance Win32_PnPSignedDriver |
    Where-Object DeviceName -match 'NVIDIA GeForce|RZ717|Radeon|AMD PSP|Killer|U\.are\.U' |
    Sort-Object DeviceName |
    Format-Table DeviceName, DriverVersion, @{ n = 'Date'; e = { $_.DriverDate.ToString('yyyy-MM-dd') } } -AutoSize |
    Out-Host

Write-Step 'Section 5 settings'
# An update can quietly reset these
$expected = @(
    @{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; Name = 'RealTimeIsUniversal'; Value = 1 }
    @{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name = 'HibernateEnabled'; Value = 0 }
    @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
    @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ExcludeWUDriversInQualityUpdate'; Value = 1 }
)
$drift = [System.Collections.Generic.List[string]]::new()
foreach ($e in $expected) {
    $value = (Get-ItemProperty $e.Key -ErrorAction SilentlyContinue).($e.Name)
    if ($value -ne $e.Value) { $drift.Add("$($e.Key)\$($e.Name) is $($value ?? 'missing'), expected $($e.Value)") }
}
if ((Get-Service DiagTrack).StartType -ne 'Disabled') { $drift.Add('the DiagTrack service is no longer disabled') }
if ($drift) {
    Write-Host "  $($drift.Count) changed, listed below" -ForegroundColor Yellow
    $drift | ForEach-Object { $todo.Add("Reset (section 5): $_") }
} else {
    Write-Host '  All as set'
}

Write-Step 'Left for you'
$todo | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
Write-Host '  - Windows Update finished in Settings; reboot if it asks'
Write-Host '  - Drivers and BIOS above, from the vendors'

$stateDir = "$env:LOCALAPPDATA\monthly-update"
New-Item -ItemType Directory -Force $stateDir | Out-Null
Set-Content "$stateDir\last-run" (Get-Date -Format 'yyyy-MM-dd')
Write-Host "`nRecorded this month's run; the reminder stays quiet until the next Patch Tuesday" -ForegroundColor Green
