$PSScriptRoot_Profile = $PSScriptRoot
if (-not $PSScriptRoot_Profile) { $PSScriptRoot_Profile = "$HOME\MyConfigurations\powershell" }

oh-my-posh init pwsh --config "gruvbox" | Invoke-Expression

# posh-git
Import-Module posh-git

# Icons
Import-Module Terminal-Icons

# PSReadLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -BellStyle None
Import-Module CompletionPredictor
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
$Env:FZF_DEFAULT_OPTS = '--height=60% --layout=reverse --info=inline --border --margin=1 --padding=1'
$Env:FZF_DEFAULT_COMMAND = 'fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
$Env:FZF_CTRL_T_COMMAND = $Env:FZF_DEFAULT_COMMAND

# Bat
$Env:BAT_THEME = 'gruvbox-dark'

# Zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Alias
Set-Alias l ls
Set-Alias g git
Set-Alias df duf

function batp { bat --style=plain @args }
function fzp { fzf --preview 'bat --style=numbers --color=always --line-range :500 {}' @args }
function keys { bat --style=plain "$PSScriptRoot_Profile\cheatsheet.md" }

# Git
. "$PSScriptRoot_Profile\git.ps1"

# Directory history
. "$PSScriptRoot_Profile\dirhistory.ps1"

# Utilities
function which ($command)
{
  Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

function y
{
  $tmp = (New-TemporaryFile).FullName
  yazi $args --cwd-file="$tmp"
  $cwd = Get-Content -Path $tmp -Encoding UTF8
  if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path)
  {
    Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
  }
  Remove-Item -Path $tmp
}
