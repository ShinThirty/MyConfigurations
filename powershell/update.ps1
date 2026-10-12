# Monthly update, attended (MIGRATION.windows.md section 15), the counterpart of mac/update.sh and
# arch/update.sh. Run from pwsh, unelevated. Runs every step's update, then every step's cleanup
# (runner.ps1 says where the steps are), and ends with what's left for you. Finishing records the
# run, which silences update_reminder.ps1 until the next Patch Tuesday.
#
# Kept to what Windows PowerShell can parse, so that it gets as far as saying it won't run there
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Run this from pwsh (PowerShell 7), not Windows PowerShell" -ForegroundColor Red
    exit 1
}
. "$PSScriptRoot\runner.ps1"

Invoke-Steps Update, Cleanup
Write-LeftForYou

$stateDir = "$env:LOCALAPPDATA\monthly-update"
New-Item -ItemType Directory -Force $stateDir | Out-Null
Set-Content "$stateDir\last-run" (Get-Date -Format 'yyyy-MM-dd')
Write-Host "`nRecorded this month's run; the reminder stays quiet until the next Patch Tuesday" -ForegroundColor Green
