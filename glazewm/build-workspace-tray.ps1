# Builds workspace-tray.cs, the tray icon with GlazeWM's focused workspace, into
# %LOCALAPPDATA%\workspace-tray\workspace-tray.exe, which config.yaml's startup command runs. The
# compiler is the one in .NET Framework 4.8, which Windows ships.
#
# The exe's product version is a hash of its inputs: the source, and this script, which holds the
# compiler's options. With -Check, nothing is built: it prints a line when the exe is missing or its
# hash isn't the inputs' now, and nothing when it's current. The monthly update (step 53) rebuilds it
# then. A failed build leaves the exe and the running copy as they were. A good one replaces the
# running copy, since Windows locks a running exe, and starts the new one if GlazeWM is running;
# otherwise GlazeWM's startup command starts it.
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$out = "$env:LOCALAPPDATA\workspace-tray"
$exe = "$out\workspace-tray.exe"
$source = "$PSScriptRoot\workspace-tray.cs"
$hash = ($source, $PSCommandPath | ForEach-Object { (Get-FileHash $_).Hash.Substring(0, 16) }) -join '-'

if ($Check) {
    if (-not (Test-Path $exe)) { "$exe isn't built" }
    elseif ((Get-Item $exe).VersionInfo.ProductVersion -ne $hash) { "$exe is older than workspace-tray.cs or this script" }
    return
}

New-Item -ItemType Directory -Force $out | Out-Null
$stamp = "$out\version.cs"
$new = "$out\workspace-tray.new.exe"
"[assembly: System.Reflection.AssemblyInformationalVersion(`"$hash`")]" | Set-Content $stamp -Encoding ascii
try {
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ `
        /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll `
        "/out:$new" $source $stamp
} finally {
    Remove-Item $stamp
}
if ($LASTEXITCODE) { Remove-Item $new -ErrorAction SilentlyContinue; exit $LASTEXITCODE }

Get-Process workspace-tray -ErrorAction SilentlyContinue | ForEach-Object { $_ | Stop-Process -Force; $_.WaitForExit(5000) | Out-Null }
Move-Item $new $exe -Force
if (Get-Process glazewm -ErrorAction SilentlyContinue) { Start-Process $exe }
