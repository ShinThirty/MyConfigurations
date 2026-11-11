# runner.ps1: the part of the monthly update and cleanup that update.ps1 and cleanup.ps1 share
# (MIGRATION.windows.md section 15), the counterpart of unix/runner.zsh. Both dot-source it.
#
# Each tool is a step: a file named NN-tool.ps1 in steps/. It returns @{ Update = { ... };
# Cleanup = { ... } }, either or both, and nothing else. The runner calls each block in a scope of
# its own below Invoke-Steps, which is how the block sees $todo, the helpers below, $repo and
# $StepFile, the file it came from. .GetNewClosure() would cut it off from them, so never use it.
# The step file's own scope is gone by the time a block runs, so a function a block needs is defined
# inside the block. A step skips itself when its tool isn't installed, reports through the helpers,
# adds what it leaves for you to $todo, and ends early with return, never exit, which ends the run.
#
# The number sets the order, and a tool keeps the number it has on macOS and Arch: 10 the OS, 20 the
# package manager, 3x toolchains, 4x shell and editor plugins, 5x the platform's own extras, 60 temp
# files, 8x checks.

function Write-Step { Write-Host "`n`e[1;34m==>`e[0m `e[1m$args`e[0m" }
function Write-Ok { Write-Host "  `e[32m✅`e[0m $args" }
function Write-Skip { Write-Host "  `e[90m•`e[0m  $args" }
function Write-Warn { Write-Host "  `e[33m⚠️`e[0m  $args" }

# Invoke-Capped <seconds> <command> <arguments>: runs the command and returns the lines it printed,
# stdout's then stderr's, or stdout's alone with -NoStderr. If it runs past <seconds>, it's stopped
# along with what it started, and $LASTEXITCODE is 124, as with timeout(1). It counts as running
# until its output closes, which a process it started can hold open after it exits
function Invoke-Capped([int]$Seconds, [string]$Command, [string[]]$Arguments, [switch]$NoStderr) {
    $psi = [Diagnostics.ProcessStartInfo]::new((Get-Command $Command -CommandType Application -TotalCount 1).Source)
    $Arguments | ForEach-Object { $psi.ArgumentList.Add($_) }
    $psi.RedirectStandardOutput = $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $p = [Diagnostics.Process]::Start($psi)
    [Threading.Tasks.Task[]]$read = $p.StandardOutput.ReadToEndAsync(), $p.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::Now.AddSeconds($Seconds)
    $done = $false
    try {
        # In short waits, so that Ctrl+C gets through
        while (-not $done -and [DateTime]::Now -lt $deadline) {
            $done = $p.WaitForExit(200) -and [Threading.Tasks.Task]::WaitAll($read, 200)
        }
    } finally {
        # Past its time, or Ctrl+C
        if (-not $done) {
            try { $p.Kill($true) } catch {}
            $null = [Threading.Tasks.Task]::WaitAll($read, 5000)
        }
    }
    $global:LASTEXITCODE = $done ? $p.ExitCode : 124
    foreach ($r in ($NoStderr ? $read[0] : $read)) {
        if ($r.IsCompletedSuccessfully) { $r.Result -split '\r?\n' }
    }
}

$repo = Split-Path $PSScriptRoot
$todo = [System.Collections.Generic.List[string]]::new()

# Invoke-Steps Update, Cleanup: every step's update, then every step's cleanup, by number
function Invoke-Steps([string[]]$Phase) {
    $files = Get-ChildItem "$PSScriptRoot\steps\*.ps1" | Sort-Object Name
    foreach ($p in $Phase) {
        foreach ($file in $files) {
            $StepFile = $file.FullName
            # An error that stops a step stops only that step, as a failing command does in zsh
            try {
                $step = & $StepFile
                if ($step.$p) { & $step.$p }
            } catch {
                $at = $_.InvocationInfo
                $where = "$(Split-Path -Leaf ($at.ScriptName ? $at.ScriptName : $StepFile)):$($at.ScriptLineNumber)"
                Write-Warn "stopped: $_ ($where)"
                $todo.Add("$($file.Name) stopped partway through its $($p.ToLower()): $_ ($where)")
            }
        }
    }
}

function Write-LeftForYou {
    if (-not $todo.Count) { return }
    Write-Step 'Left for you'
    $todo | ForEach-Object { Write-Host "  `e[33m- $_`e[0m" }
}
