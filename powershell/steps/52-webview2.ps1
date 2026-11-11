# The WebView2 Runtime's firewall rules (MIGRATION.windows.md section 12.1). Each runtime version Edge
# Update installs adds a rule for its own folder, and the rule stays once the next version replaces
# that folder. The cleanup deletes the rules you approve from one elevated window, by starting this
# file as admin with -Remove: run that way, it deletes them and writes the result file instead of
# returning its blocks.
param(
    # The approved rules' names, as {GUID},{GUID}
    [ValidatePattern('^\{[0-9A-Fa-f-]{36}\}(,\{[0-9A-Fa-f-]{36}\})*$')][string]$Remove
)

$step = @{
    Cleanup = {
        param([string]$Remove)
        $resultFile = "$env:LOCALAPPDATA\monthly-update\webview2-result.json"

        # The runtime's rules whose version folder is gone
        function Get-StaleRule {
            Get-NetFirewallRule -Group 'Microsoft Edge WebView2 Runtime' -ErrorAction SilentlyContinue | ForEach-Object {
                $program = ($_ | Get-NetFirewallApplicationFilter).Program
                if ($program -and -not (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($program)))) {
                    [pscustomobject]@{ Name = $_.Name; Version = Split-Path (Split-Path $program) -Leaf }
                }
            }
        }

        if ($Remove) {
            # The elevated half. The rules are read again, so one whose version came back stays
            $stale = @(Get-StaleRule)
            $results = foreach ($name in $Remove -split ',') {
                $r = $stale | Where-Object Name -eq $name
                $result = [pscustomobject]@{ Name = $name; Version = $r.Version; Ok = $false; Message = '' }
                if (-not $r) { $result.Message = 'already gone, or its version is back' }
                else {
                    try { Remove-NetFirewallRule -Name $name -ErrorAction Stop; $result.Ok = $true }
                    catch { $result.Message = "$_" }
                }
                $result
            }
            New-Item -ItemType Directory -Force (Split-Path $resultFile) | Out-Null
            ConvertTo-Json -InputObject @($results) | Set-Content $resultFile
            return
        }

        Write-Step 'Cleanup: WebView2 firewall rules'
        $stale = @(Get-StaleRule)
        if (-not $stale) { Write-Skip 'none left from older versions'; return }
        Write-Host "  The runtime's older versions are gone, but their rules stay: $($stale.Version -join ', ')"
        if ((Read-Host "  Delete $(($stale.Count -eq 1) ? 'it' : "all $($stale.Count)")? [y/N]") -ne 'y') { return }

        Remove-Item $resultFile -ErrorAction SilentlyContinue
        try {
            Start-Process (Get-Process -Id $PID).Path -Verb RunAs -Wait -ErrorAction Stop `
                -ArgumentList '-NoProfile', '-File', "`"$StepFile`"", '-Remove', ($stale.Name -join ',')
        } catch {
            $todo.Add('WebView2 firewall rules: the UAC prompt was declined, so none were deleted. Run powershell\cleanup.ps1 to try again')
            return
        }
        if (-not (Test-Path $resultFile)) {
            $todo.Add("WebView2 firewall rules: the elevated window closed without reporting back. Get-NetFirewallRule -Group 'Microsoft Edge WebView2 Runtime' shows what is left")
            return
        }
        $results = @(Get-Content $resultFile -Raw | ConvertFrom-Json)
        $deleted = @($results | Where-Object Ok)
        if ($deleted) { Write-Ok "deleted the rules for $($deleted.Version -join ', ')" }
        $results | Where-Object { -not $_.Ok } | ForEach-Object { $todo.Add("WebView2's firewall rule for $($_.Version ?? $_.Name) wasn't deleted: $($_.Message)") }
        Remove-Item $resultFile
    }
}

if ($Remove) { & $step.Cleanup $Remove } else { $step }
