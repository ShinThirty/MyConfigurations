# Monthly update reminder (MIGRATION.windows.md section 15). From the day after Patch Tuesday
# until update.ps1 records a run, shows a toast at most once a day.
#   .\update_reminder.ps1 -Register    register the scheduled task (from pwsh, once per install)
# The task runs it through Update-Reminder.vbs under Windows PowerShell, which has the WinRT
# toast API that pwsh lacks. Keep this file ASCII: Windows PowerShell reads it in the ANSI code page.
param([switch]$Register)

if ($Register) {
    # At logon, plus daily for a session left open for days; StartWhenAvailable catches up a
    # daily run missed while the machine was off or in Arch
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'Monthly Update Reminder' -Force `
        -Action (New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$PSScriptRoot\Update-Reminder.vbs`"") `
        -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME), (New-ScheduledTaskTrigger -Daily -At '12:00') `
        -Settings $settings | Out-Null
    Write-Host 'Registered scheduled task: Monthly Update Reminder (at logon and daily)'
    return
}

$stateDir = "$env:LOCALAPPDATA\monthly-update"

# Cumulative updates ship on Patch Tuesday, the second Tuesday (the 8th-14th)
function Get-DueDate([datetime]$month) {
    $day = Get-Date -Year $month.Year -Month $month.Month -Day 8
    while ($day.DayOfWeek -ne 'Tuesday') { $day = $day.AddDays(1) }
    $day.Date.AddDays(1)
}
$today = (Get-Date).Date
$due = Get-DueDate $today
if ($today -lt $due) { $due = Get-DueDate $today.AddMonths(-1) }

function Get-Stamp($name) {
    $file = "$stateDir\$name"
    if (Test-Path $file) { [datetime](Get-Content $file) } else { [datetime]::MinValue }
}
if ((Get-Stamp 'last-run') -ge $due -or (Get-Stamp 'last-reminder') -ge $today) { return }

$xml = @"
<toast scenario="reminder">
  <visual><binding template="ToastGeneric">
    <text>Monthly update</text>
    <text>Run powershell\update.ps1 from MyConfigurations, then check drivers and the BIOS</text>
    <text>MIGRATION.windows.md section 15</text>
  </binding></visual>
  <actions><action activationType="system" arguments="dismiss" content="" /></actions>
</toast>
"@
[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
$doc = [Windows.Data.Xml.Dom.XmlDocument]::new()
$doc.LoadXml($xml)
# Windows PowerShell's own app ID: it already has the Start menu shortcut a toast needs
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($doc))

New-Item -ItemType Directory -Force $stateDir | Out-Null
Set-Content "$stateDir\last-reminder" $today.ToString('yyyy-MM-dd')
