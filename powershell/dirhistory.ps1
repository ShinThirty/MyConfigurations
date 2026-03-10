# Directory history navigation (mirrors oh-my-zsh dirhistory plugin)
# Alt+Left/Right: back/forward through cd history
# Alt+Up: parent directory
# Alt+Down: first subdirectory

$global:dirhistory_past = [System.Collections.Generic.List[string]]::new()
$global:dirhistory_future = [System.Collections.Generic.List[string]]::new()
$global:dirhistory_navigating = $false

# Track directory changes
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($sender, $e)
    if (-not $global:dirhistory_navigating) {
        $global:dirhistory_past.Add($e.OldPath.Path)
        if ($global:dirhistory_past.Count -gt 30) {
            $global:dirhistory_past.RemoveAt(0)
        }
        $global:dirhistory_future.Clear()
    }
}

function _dirhistory_back {
    if ($global:dirhistory_past.Count -eq 0) { return }
    $prev = $global:dirhistory_past[-1]
    $global:dirhistory_past.RemoveAt($global:dirhistory_past.Count - 1)
    $global:dirhistory_future.Add($PWD.Path)
    $global:dirhistory_navigating = $true
    Set-Location -LiteralPath $prev
    $global:dirhistory_navigating = $false
}

function _dirhistory_forward {
    if ($global:dirhistory_future.Count -eq 0) { return }
    $next = $global:dirhistory_future[-1]
    $global:dirhistory_future.RemoveAt($global:dirhistory_future.Count - 1)
    $global:dirhistory_past.Add($PWD.Path)
    $global:dirhistory_navigating = $true
    Set-Location -LiteralPath $next
    $global:dirhistory_navigating = $false
}

function _dirhistory_up {
    $parent = Split-Path -Parent $PWD.Path
    if ($parent -and $parent -ne $PWD.Path) {
        Set-Location -LiteralPath $parent
    }
}

function _dirhistory_down {
    $first = Get-ChildItem -Directory -Force:$false | Sort-Object Name | Select-Object -First 1
    if ($first) {
        Set-Location -LiteralPath $first.FullName
    }
}

Set-PSReadLineKeyHandler -Chord 'Alt+LeftArrow' -ScriptBlock {
    _dirhistory_back
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -ScriptBlock {
    _dirhistory_forward
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

Set-PSReadLineKeyHandler -Chord 'Alt+UpArrow' -ScriptBlock {
    _dirhistory_up
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

Set-PSReadLineKeyHandler -Chord 'Alt+DownArrow' -ScriptBlock {
    _dirhistory_down
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}
