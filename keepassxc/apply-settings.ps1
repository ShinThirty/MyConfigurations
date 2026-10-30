<#
Merges keepassxc.ini into KeePassXC's own settings file, and has Windows start it at sign-in: the
Windows counterpart of apply-settings.sh. scoop's KeePassXC is portable (the .portable file beside
it), so its file is ~\scoop\persist\keepassxc\config\keepassxc.ini, which it rewrites when it saves
its settings and when it quits; quit it first, from its tray icon, since with MinimizeOnClose closing
its window only hides it. Keys keepassxc.ini doesn't name are left alone, KeeShare's private key
among them, so rerunning is harmless. The previous file is kept as keepassxc.ini.bak; with no file
yet, KeePassXC starts from keepassxc.ini's.

Starting at sign-in is a Run entry of its own, KeePassXC database: KeePassXC through scoop's
current link, so updates keep it working, with the database -Database names, which MinimizeOnStartup
keeps locked in the tray. The path stays in this machine's registry, out of the repo, and a rerun
without -Database keeps it. KeePassXC's own entry, KeePassXC, from its Settings > General > Startup
checkbox, is the bare program, written again each time its settings are saved, so it can't carry the
database; this removes it, so leave the checkbox off. A database KeePassXC can't find at sign-in, with
Z: not reconnected say, it skips without a word, and KeePassXC-Browser then finds none open.
Per user, so no elevation.

-Check writes nothing and lists what differs instead. steps/80-settings.ps1 runs it.
#>
param([switch]$Check, [string]$Database)
$ErrorActionPreference = 'Stop'

$ini = "$HOME\scoop\persist\keepassxc\config\keepassxc.ini"
$exe = "`"$HOME\scoop\apps\keepassxc\current\KeePassXC.exe`""
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$name = 'KeePassXC database'
# Settings > Apps > Startup's switch, which Task Manager's Startup apps also sets: an odd first byte is off
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'

$entries = Get-ItemProperty $run -ErrorAction SilentlyContinue
$command = $entries.$name
if ($Database) {
    if (-not (Test-Path -LiteralPath $Database -PathType Leaf)) { throw "There's no database at $Database" }
    $Database = (Resolve-Path -LiteralPath $Database).ProviderPath
} elseif ($command -match '^"[^"]+" "(.+)"$') {
    $Database = $Matches[1]
}
$startCommand = $Database ? "$exe `"$Database`"" : $exe

# keepassxc.ini's settings, by section, in order
$want = [ordered]@{}
$section = ''
foreach ($line in Get-Content "$PSScriptRoot\keepassxc.ini") {
    if ($line -match '^\s*([#;]|$)') { continue }
    if ($line -match '^\[(.+)\]$') {
        $section = $Matches[1]
        if (-not $want.Contains($section)) { $want[$section] = [ordered]@{} }
        continue
    }
    $key, $value = $line -split '=', 2
    $want[$section][$key] = $value
}

# KeePassXC's file, and each of those settings it has otherwise
$lines = @(if (Test-Path $ini) { Get-Content $ini })
$have = @{}
$section = ''
foreach ($line in $lines) {
    if ($line -match '^\[(.+)\]$') { $section = $Matches[1] }
    elseif ($line -match '^([^=]+)=(.*)$') { $have["$section/$($Matches[1])"] = $Matches[2] }
}
function Show($value, $empty) { if ($null -eq $value) { 'unset' } elseif ($value -eq '') { $empty } else { $value } }
$changes = @(foreach ($s in $want.Keys) {
    foreach ($key in $want[$s].Keys) {
        $now = $have["$s/$key"]
        if ($now -cne $want[$s][$key]) { "$s/$key is $(Show $now 'empty'), keepassxc.ini has $(Show $want[$s][$key] 'it empty')" }
    }
})

$off = (Get-ItemProperty $approved -ErrorAction SilentlyContinue).$name
$startup = @(
    if (-not $command) { "Run entry, $name, is missing, so it doesn't start at sign-in; -Database names the database" }
    elseif (-not $Database) { "Run entry, $name, opens no database; -Database names it" }
    elseif ($command -ne $startCommand) { "Run entry, $name, runs $command, not $startCommand" }
    if ($off -and $off[0] -band 1) { "Run entry, $name, is switched off in Settings > Apps > Startup" }
)

if ($Check) {
    if (Test-Path $ini) { $changes } else { "settings file, $($ini.Replace($HOME, '~')), isn't there yet" }
    $startup
    return
}

if (-not $changes) {
    Write-Host "KeePassXC's settings are already keepassxc.ini's"
} elseif (Get-Process KeePassXC -ErrorAction SilentlyContinue) {
    throw 'KeePassXC is running and would write its own settings back when it quits; quit it from its tray icon first (closing its window only hides it)'
} else {
    # keepassxc.ini's value in place of each one KeePassXC's file has, and the keys it lacks at the end of
    # their section. Blank lines wait, so those go before the blank line that ends it.
    $out = [System.Collections.Generic.List[string]]::new()
    $done = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    function Add-Missing {
        if (-not $want[$section]) { return }
        foreach ($key in $want[$section].Keys) {
            if (-not $done.Contains("$section/$key")) { $out.Add("$key=$($want[$section][$key])") }
        }
    }
    $section = ''
    $blanks = 0
    foreach ($line in $lines) {
        if ($line -eq '') { $blanks++; continue }
        if ($line -match '^\[(.+)\]$') {
            Add-Missing
            $section = $Matches[1]
        } elseif ($line -match '^([^=]+)=' -and $want[$section] -and $want[$section].Contains($Matches[1])) {
            $key = $Matches[1]
            $line = "$key=$($want[$section][$key])"
            [void]$done.Add("$section/$key")
        }
        while ($blanks) { $out.Add(''); $blanks-- }
        $out.Add($line)
    }
    Add-Missing
    foreach ($s in $want.Keys) {
        if ($lines -contains "[$s]") { continue }
        if ($out.Count) { $out.Add('') }
        $out.Add("[$s]")
        $section = $s
        Add-Missing
    }
    New-Item -ItemType Directory -Force (Split-Path $ini) | Out-Null
    if (Test-Path $ini) { Copy-Item $ini "$ini.bak" }
    Set-Content "$ini.tmp" $out
    Move-Item -Force "$ini.tmp" $ini
    Write-Host "Merged keepassxc.ini into $($ini.Replace($HOME, '~')): $($changes.Count) settings changed"
}

if ($command -ne $startCommand) { Set-ItemProperty $run $name $startCommand }
if ($off -and $off[0] -band 1) { Remove-ItemProperty $approved $name }
if ($null -ne $entries.KeePassXC) {
    Remove-ItemProperty $run KeePassXC
    Write-Host "Removed KeePassXC's own Run entry, which its settings write again without the database"
}
if ($Database) {
    Write-Host "The Run entry $name starts KeePassXC at sign-in with $Database"
} else {
    Write-Host "The Run entry $name starts KeePassXC at sign-in with no database; -Database names one"
}
