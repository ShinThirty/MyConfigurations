$TargetDirectory = "$HOME\.config\aria2"
if (-not (Test-Path -Path $TargetDirectory))
{
	New-Item -Path $TargetDirectory -ItemType Directory | Out-Null
}

Copy-Item -Path ..\aria2.conf -Destination $TargetDirectory
Copy-Item -Path .\Start-Aria2.vbs -Destination $TargetDirectory
Copy-Item -Path .\update_trackers.ps1 -Destination $TargetDirectory
Copy-Item -Path .\Update-Trackers.vbs -Destination $TargetDirectory

if (-not (Test-Path -Path "$TargetDirectory\aria2.session"))
{
	New-Item -ItemType File -Path "$TargetDirectory\aria2.session"
}
