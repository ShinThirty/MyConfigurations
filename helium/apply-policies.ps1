<#
Writes policies.json into HKLM\SOFTWARE\Policies\Helium, where Helium reads its policies on Windows
(MIGRATION.windows.md section 12.1). Run it elevated, and again after changing policies.json. It
rewrites the whole key, so a policy dropped from the file goes too:

    sudo pwsh -NoProfile -File helium\apply-policies.ps1

-Check needs no elevation and writes nothing; it lists what differs from the file instead.
steps/80-settings.ps1 runs it. A list policy (ExtensionInstallForcelist) becomes a subkey of REG_SZ
values named 1, 2, ...; a true/false or a number becomes a REG_DWORD, and a string a REG_SZ.
#>
param([switch]$Check)
$ErrorActionPreference = 'Stop'

$key = 'HKLM:\SOFTWARE\Policies\Helium'
$policies = Get-Content "$PSScriptRoot\policies.json" -Raw | ConvertFrom-Json -AsHashtable
$values = foreach ($name in $policies.Keys) {
    $v = $policies[$name]
    if ($v -is [array]) {
        for ($i = 0; $i -lt $v.Count; $i++) { @{ Key = $name; Name = "$($i + 1)"; Value = $v[$i]; Type = 'String' } }
    } elseif ($v -is [string]) {
        @{ Key = ''; Name = $name; Value = $v; Type = 'String' }
    } elseif ($v -is [bool] -or $v -is [int] -or $v -is [long]) {
        @{ Key = ''; Name = $name; Value = [int]$v; Type = 'DWord' }
    } else {
        throw "$name`: no registry form for a $($v.GetType().Name) policy here yet"
    }
}

if ($Check) {
    # Each value as 'subkey\name = value', the file's against the registry's
    $want = $values | ForEach-Object { "$(($_.Key, $_.Name) -ne '' -join '\') = $($_.Value)" }
    $have = if (Test-Path $key) {
        $root = (Get-Item $key).Name
        @(Get-Item $key) + @(Get-ChildItem $key -Recurse) | ForEach-Object {
            $k = $_
            $sub = $k.Name.Substring($root.Length).TrimStart('\')
            $k.GetValueNames() | ForEach-Object { "$(($sub, $_) -ne '' -join '\') = $($k.GetValue($_))" }
        }
    }
    Compare-Object @($want) @($have) | ForEach-Object {
        if ($_.SideIndicator -eq '<=') { "$($_.InputObject) is missing" } else { "$($_.InputObject) isn't in policies.json" }
    }
    return
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    throw 'Writing HKLM needs elevation: sudo pwsh -NoProfile -File helium\apply-policies.ps1'
}
if (Test-Path $key) { Remove-Item $key -Recurse }
New-Item $key | Out-Null
foreach ($v in $values) {
    $k = $v.Key ? "$key\$($v.Key)" : $key
    if (-not (Test-Path $k)) { New-Item $k | Out-Null }
    New-ItemProperty $k -Name $v.Name -Value $v.Value -PropertyType $v.Type | Out-Null
}
Write-Host "Wrote $(@($values).Count) values from policies.json under HKLM\SOFTWARE\Policies\Helium"
