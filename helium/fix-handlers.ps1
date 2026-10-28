<#
Adds the profile folder to the commands Helium registers with Windows, so links opened from other
apps land in its profile (MIGRATION.windows.md section 12.1). Helium registers itself as a browser on
its first start: Clients\StartMenuInternet\Helium.<suffix>, the HeliumHTM.<suffix> and
HeliumPDF.<suffix> ProgIDs and the helium: protocol, all through scoop's current link. Its commands
leave out the profile folder, ~\scoop\persist\helium\User Data, which only scoop's shortcut and shim
pass, and without it a link would open a second, empty profile. This adds --user-data-dir to each of
them. Per user, so no elevation; rerunning is harmless.

-Check writes nothing and lists the commands still without it. steps/80-settings.ps1 runs it, in case
Helium writes its registration again.
#>
param([switch]$Check)
$ErrorActionPreference = 'Stop'

$exe = "`"$HOME\scoop\apps\helium\current\chrome.exe`""
$flag = "--user-data-dir=`"$HOME\scoop\persist\helium\User Data`""

$clients = @(Get-ChildItem 'HKCU:\Software\Clients\StartMenuInternet' -ErrorAction SilentlyContinue | Where-Object PSChildName -like 'Helium*')
if (-not $clients) {
    if ($Check) { return }
    throw "Helium hasn't registered itself yet: start it once, then run this again"
}
# The client keys, the ProgIDs their capabilities name, and the helium: protocol
$keys = @(
    $clients.PSPath
    foreach ($c in $clients) {
        foreach ($a in 'FileAssociations', 'URLAssociations') {
            $assoc = Get-Item "$($c.PSPath)\Capabilities\$a" -ErrorAction SilentlyContinue
            if ($assoc) { $assoc.GetValueNames() | ForEach-Object { "HKCU:\Software\Classes\$($assoc.GetValue($_))" } }
        }
    }
    'HKCU:\Software\Classes\helium'
) | Sort-Object -Unique | Where-Object { Test-Path $_ }

$fixed = 0
foreach ($k in $keys) {
    foreach ($key in @(Get-Item $k) + @(Get-ChildItem $k -Recurse)) {
        foreach ($name in $key.GetValueNames()) {
            $command = $key.GetValue($name)
            if ($command -isnot [string] -or -not $command.StartsWith($exe, 'OrdinalIgnoreCase') -or $command.Contains('--user-data-dir')) { continue }
            if ($Check) { "$($key.Name -replace '^HKEY_CURRENT_USER', 'HKCU')\$($name ? $name : '(default)')"; continue }
            Set-ItemProperty $key.PSPath -Name ($name ? $name : '(default)') -Value $command.Insert($exe.Length, " $flag")
            $fixed++
        }
    }
}
if (-not $Check) { Write-Host "Added the profile folder to $fixed of Helium's registered commands" }
