# Create stub profile that dot-sources the real profile from dotfiles
$stubDir = "$HOME\OneDrive\Documents\PowerShell"
$stubPath = "$stubDir\Microsoft.PowerShell_profile.ps1"
$stubContent = '. "$HOME\MyConfigurations\powershell\profile.ps1"'

if (-not (Test-Path $stubDir)) {
    New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
}

if ((Test-Path $stubPath) -and (Get-Content $stubPath -Raw).Trim() -eq $stubContent) {
    Write-Host "  [skip] profile stub already exists" -ForegroundColor Yellow
} else {
    Set-Content -Path $stubPath -Value $stubContent
    Write-Host "  [link] profile stub created at $stubPath" -ForegroundColor Green
}

# Install PSGallery modules
$modules = @(
    'CompletionPredictor'
    'posh-git'
    'Terminal-Icons'
    'PSFzf'
)

foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module..." -ForegroundColor Green
        Install-Module -Name $module -Scope CurrentUser -Force
    } else {
        Write-Host "  [skip] $module already installed" -ForegroundColor Yellow
    }
}
