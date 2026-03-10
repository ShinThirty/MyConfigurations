Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DOTFILES = $PSScriptRoot

function Setup-Symlink {
    param(
        [string]$Source,
        [string]$Link
    )

    $parent = Split-Path -Parent $Link
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $shortLink = $Link -replace [regex]::Escape($HOME), "~"

    if ((Test-Path $Link) -and ((Get-Item $Link).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Write-Host "  [skip] $shortLink" -ForegroundColor Yellow
    } else {
        if (Test-Path $Link) {
            Remove-Item -Path $Link -Recurse -Force
        }

        $isDir = (Test-Path $Source) -and (Get-Item $Source).PSIsContainer
        if ($isDir) {
            New-Item -ItemType SymbolicLink -Path $Link -Target $Source | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $Link -Target $Source | Out-Null
        }

        Write-Host "  [link] $shortLink" -ForegroundColor Green
    }
}

function Setup-SymlinksFromMap {
    param([string]$MapFile)

    Get-Content $MapFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }

        $parts = $line -split ":", 2
        $source = $ExecutionContext.InvokeCommand.ExpandString($parts[0])
        $target = $ExecutionContext.InvokeCommand.ExpandString($parts[1])

        # Normalize forward slashes to backslashes
        $source = $source -replace "/", "\"
        $target = $target -replace "/", "\"

        Setup-Symlink -Source $source -Link $target
    }
}

$APPDATA = $env:APPDATA
$LOCALAPPDATA = $env:LOCALAPPDATA

Setup-SymlinksFromMap "$DOTFILES\symlinks.windows"
