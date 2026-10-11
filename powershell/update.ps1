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
# A bump pulled from another machine changes package.toml's hashes under the
# plugins deployed here, so ya takes them for local edits and aborts
ya pkg upgrade
if ($LASTEXITCODE) { $todo.Add('ya pkg upgrade failed: if it says you modified a plugin you never touched, package.toml was bumped elsewhere: ya pkg install --discard, then ya pkg upgrade') }
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

Write-Step 'Runbook settings'
# An update can quietly reset these, and an app can put its Run entry back
$p = 'HKLM:\SOFTWARE\Policies\Microsoft'
$expected = [ordered]@{
    # 5.1
    'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' = @{ RealTimeIsUniversal = 1 }
    'HKLM:\SYSTEM\CurrentControlSet\Control\Power' = @{ HibernateEnabled = 0 }
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' = @{ HiberbootEnabled = 0 }
    # 5.2
    'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' = @{ 'Scancode Map' = '00000000000000000300000001003A003A00010000000000' }
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' = @{ AppsUseLightTheme = 0; SystemUsesLightTheme = 0 }
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' = @{ '{645FF040-5081-101B-9F08-00AA002F954E}' = 1 }
    'HKCU:\Control Panel\Mouse' = @{ MouseSpeed = '0'; MouseThreshold1 = '0'; MouseThreshold2 = '0' }
    'HKCU:\Control Panel\Keyboard' = @{ KeyboardDelay = '0'; InitialKeyboardIndicators = '2' }
    'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' = @{ InitialKeyboardIndicators = '2147483650' }
    'HKCU:\Control Panel\Accessibility\StickyKeys' = @{ Flags = '506' }
    # 5.3
    "$p\Windows\DataCollection" = @{ AllowTelemetry = 0; DoNotShowFeedbackNotifications = 1 }
    "$p\Windows\Windows Error Reporting" = @{ Disabled = 1 }
    "$p\Windows\AdvertisingInfo" = @{ DisabledByGroupPolicy = 1 }
    "$p\Windows\System" = @{ PublishUserActivities = 0; UploadUserActivities = 0 }
    "$p\Windows\CloudContent" = @{ DisableWindowsConsumerFeatures = 1 }
    'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' = @{ DisableTailoredExperiencesWithDiagnosticData = 1 }
    'HKCU:\Software\Policies\Microsoft\Windows\Explorer' = @{ DisableSearchBoxSuggestions = 1 }
    # 5.3 and 5.5
    "$p\Edge" = @{ DiagnosticData = 0; StartupBoostEnabled = 0; BackgroundModeEnabled = 0 }
    # 5.4
    "$p\Windows\WindowsUpdate" = @{ ExcludeWUDriversInQualityUpdate = 1 }
    # 5.5
    'HKCU:\System\GameConfigStore' = @{ GameDVR_Enabled = 0 }
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' = @{ AppCaptureEnabled = 0 }
    "$p\Windows\GameDVR" = @{ AllowGameDVR = 0 }
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{
        SoftLandingEnabled = 0; 'SubscribedContent-338389Enabled' = 0; SystemPaneSuggestionsEnabled = 0
    }
}
$drift = [System.Collections.Generic.List[string]]::new()
foreach ($key in $expected.Keys) {
    $actual = Get-ItemProperty $key -ErrorAction SilentlyContinue
    foreach ($name in $expected[$key].Keys) {
        $want = $expected[$key][$name]
        $value = $actual.$name
        if ($value -is [byte[]]) { $value = [Convert]::ToHexString($value) }
        if ($value -ne $want) { $drift.Add("$key\$name is $($value ?? 'missing'), expected $want (section 5)") }
    }
}
if ((Get-Service DiagTrack).StartType -ne 'Disabled') { $drift.Add('the DiagTrack service is no longer disabled (section 5.3)') }
if ([Environment]::GetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'User') -ne '1') {
    $drift.Add('POWERSHELL_TELEMETRY_OPTOUT is no longer set (section 5.3)')
}
$tips = @(Get-ScheduledTask -TaskPath '\SoftLanding\*' -ErrorAction SilentlyContinue | Where-Object State -ne 'Disabled')
if ($tips) { $drift.Add("$($tips.Count) \SoftLanding\ tip tasks are enabled (section 5.5)") }
$runNames = 'HKCU:', 'HKLM:' | ForEach-Object { (Get-Item "$_\Software\Microsoft\Windows\CurrentVersion\Run").GetValueNames() }
$unwanted = [ordered]@{ 'Logitech Download Assistant' = '5.4'; 'MicrosoftEdgeAutoLaunch_*' = '5.5'; 'Flow.Launcher' = '9' }
foreach ($pattern in $unwanted.Keys) {
    $runNames | Where-Object { $_ -like $pattern } | ForEach-Object { $drift.Add("the Run key has $_ again (section $($unwanted[$pattern]))") }
}
if ($drift) {
    Write-Host "  $($drift.Count) changed, listed below" -ForegroundColor Yellow
    $drift | ForEach-Object { $todo.Add("Reset: $_") }
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
