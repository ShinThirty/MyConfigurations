<#
Merges keepassxc.ini into KeePassXC's own settings file, and keepassxc_local.ini into the one it
keeps for settings that stay on the machine, and has Windows start it at sign-in: the Windows
counterpart of apply-settings.sh. It sets this machine's BackupFilePathPattern too, where KeePassXC
copies a database before saving it: %LOCALAPPDATA%\KeePassXC\backup. scoop's KeePassXC is portable
(the .portable file beside it), so its files are keepassxc.ini and keepassxc_local.ini in
~\scoop\persist\keepassxc\config, which it rewrites when it saves its settings and when it quits;
quit it first, from its tray icon, since with MinimizeOnClose closing its window only hides it. Keys
the two don't name are left alone, KeeShare's private key among them, so rerunning is harmless. Each
previous file is kept beside it, with .bak added; with no file yet, KeePassXC starts from these
settings.

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

$config = "$HOME\scoop\persist\keepassxc\config"
# keepassxc.ini's BackupBeforeSave copies the database here before each save. KeePassXC expands
# {DB_FILENAME}, but not environment variables, and its file reads a backslash as the start of an
# escape, so it's written in full, with forward slashes
$backup = ($env:LOCALAPPDATA -replace '\\', '/') + '/KeePassXC/backup/{DB_FILENAME}.old.kdbx'
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

# Adds the settings in an ini's lines to $want, by section, in order, and where each value is from
function Add-Settings($want, $from, $lines, $source) {
    $section = ''
    foreach ($line in $lines) {
        if ($line -match '^\s*([#;]|$)') { continue }
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1]
            if (-not $want.Contains($section)) { $want[$section] = [ordered]@{} }
            continue
        }
        $key, $value = $line -split '=', 2
        $want[$section][$key] = $value
        $from["$section/$key"] = $source
    }
}
function Show($value, $empty) { if ($null -eq $value) { 'unset' } elseif ($value -eq '') { $empty } else { $value } }

# KeePassXC's two files: the repo's settings for each, with this machine's own after them, what the
# file has, and each setting that differs
$specs = @(
    @{ Path = "$config\keepassxc.ini"; Name = 'settings file'; Repo = 'keepassxc.ini'; Own = @('[General]', "BackupFilePathPattern=$backup") }
    @{ Path = "$config\keepassxc_local.ini"; Name = 'local settings file'; Repo = 'keepassxc_local.ini'; Own = @() }
)
$files = foreach ($spec in $specs) {
    $want = [ordered]@{}
    $from = @{}
    Add-Settings $want $from (Get-Content "$PSScriptRoot\$($spec.Repo)") "$($spec.Repo) has"
    Add-Settings $want $from $spec.Own 'apply-settings.ps1 sets'
    $lines = @(if (Test-Path $spec.Path) { Get-Content $spec.Path })
    $have = @{}
    $section = ''
    foreach ($line in $lines) {
        if ($line -match '^\[(.+)\]$') { $section = $Matches[1] }
        elseif ($line -match '^([^=]+)=(.*)$') { $have["$section/$($Matches[1])"] = $Matches[2] }
    }
    $changes = @(foreach ($s in $want.Keys) {
        foreach ($key in $want[$s].Keys) {
            $now = $have["$s/$key"]
            if ($now -cne $want[$s][$key]) { "$s/$key is $(Show $now 'empty'), $($from["$s/$key"]) $(Show $want[$s][$key] 'it empty')" }
        }
    })
    [pscustomobject]@{ Path = $spec.Path; Name = $spec.Name; Repo = $spec.Repo; Want = $want; Lines = $lines; Changes = $changes }
}

$off = (Get-ItemProperty $approved -ErrorAction SilentlyContinue).$name
$startup = @(
    if (-not $command) { "Run entry, $name, is missing, so it doesn't start at sign-in; -Database names the database" }
    elseif (-not $Database) { "Run entry, $name, opens no database; -Database names it" }
    elseif ($command -ne $startCommand) { "Run entry, $name, runs $command, not $startCommand" }
    if ($off -and $off[0] -band 1) { "Run entry, $name, is switched off in Settings > Apps > Startup" }
)

if ($Check) {
    foreach ($f in $files) {
        if (Test-Path $f.Path) { $f.Changes } else { "$($f.Name), $($f.Path.Replace($HOME, '~')), isn't there yet" }
    }
    $startup
    return
}

$pending = @($files | Where-Object { $_.Changes.Count })
if (-not $pending) {
    Write-Host "KeePassXC's settings are already keepassxc.ini's and keepassxc_local.ini's"
} elseif (Get-Process KeePassXC -ErrorAction SilentlyContinue) {
    throw 'KeePassXC is running and would write its own settings back when it quits; quit it from its tray icon first (closing its window only hides it)'
} else {
    foreach ($f in $pending) {
        # The repo's value in place of each one KeePassXC's file has, and the keys it lacks at the end of
        # their section. Blank lines wait, so those go before the blank line that ends it.
        $want = $f.Want
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
        foreach ($line in $f.Lines) {
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
            if ($f.Lines -contains "[$s]") { continue }
            if ($out.Count) { $out.Add('') }
            $out.Add("[$s]")
            $section = $s
            Add-Missing
        }
        New-Item -ItemType Directory -Force (Split-Path $f.Path) | Out-Null
        if (Test-Path $f.Path) { Copy-Item $f.Path "$($f.Path).bak" }
        Set-Content "$($f.Path).tmp" $out
        Move-Item -Force "$($f.Path).tmp" $f.Path
        Write-Host "Merged $($f.Repo) into $($f.Path.Replace($HOME, '~')): $($f.Changes.Count) settings changed"
    }
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
