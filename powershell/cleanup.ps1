# Monthly cleanup (MIGRATION.windows.md section 15), the counterpart of mac/cleanup.sh and
# arch/cleanup.sh: every step's cleanup, which update.ps1 runs last. Run it on its own after
# installing a vendor driver, to clear the version that one replaced. From pwsh, unelevated: the
# driver packages you approve are deleted from one elevated window.
#
# Kept to what Windows PowerShell can parse, so that it gets as far as saying it won't run there
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Run this from pwsh (PowerShell 7), not Windows PowerShell" -ForegroundColor Red
    exit 1
}
. "$PSScriptRoot\runner.ps1"

Invoke-Steps Cleanup
Write-LeftForYou
