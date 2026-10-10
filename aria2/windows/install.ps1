param(
	# Replaces aria2.conf's dir=${HOME}/Downloads in the installed copy, e.g. D:\Downloads
	[string]$DownloadDir
)

$TargetDirectory = "$HOME\.config\aria2"
if (-not (Test-Path -Path $TargetDirectory))
{
	New-Item -Path $TargetDirectory -ItemType Directory | Out-Null
}

Copy-Item -Path ..\aria2.conf -Destination $TargetDirectory
if ($DownloadDir)
{
	$Conf = "$TargetDirectory\aria2.conf"
	(Get-Content $Conf) -replace '^dir=.*', "dir=$DownloadDir" | Set-Content $Conf
}
Copy-Item -Path .\Start-Aria2.vbs -Destination $TargetDirectory
Copy-Item -Path .\update_trackers.ps1 -Destination $TargetDirectory
Copy-Item -Path .\Update-Trackers.vbs -Destination $TargetDirectory

if (-not (Test-Path -Path "$TargetDirectory\aria2.session"))
{
	New-Item -ItemType File -Path "$TargetDirectory\aria2.session"
}

# Start-Aria2.vbs waits on aria2c, so the logon task runs as long as aria2 does.
# Task Scheduler's default 3-day execution limit would kill it; zero disables the limit.
$Aria2Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
	-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Aria2" -Force `
	-Action (New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$TargetDirectory\Start-Aria2.vbs`"") `
	-Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) `
	-Settings $Aria2Settings | Out-Null

# Weekly like the systemd timer; StartWhenAvailable catches up a missed run (Persistent=true)
$TrackerSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
	-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Aria2 Update Trackers" -Force `
	-Action (New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$TargetDirectory\Update-Trackers.vbs`"") `
	-Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "00:00") `
	-Settings $TrackerSettings | Out-Null

Write-Host "Registered scheduled tasks: Aria2 (at logon), Aria2 Update Trackers (weekly)"
