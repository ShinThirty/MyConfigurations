# 1. Define paths
$trackerUrl = "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt"
$confPath = "$HOME\.config\aria2\aria2.conf"

# 2. Download and format the list
$trackers = (Invoke-RestMethod $trackerUrl) -split "\r?\n" | Where-Object { $_ -ne "" }
$trackerString = "bt-tracker=" + ($trackers -join ",")

# 3. Read config, remove old tracker line, add new one
$currentConfig = Get-Content $confPath
$newConfig = $currentConfig | Where-Object { $_ -notmatch "^bt-tracker=" }
$newConfig += $trackerString

# 4. Save file
$newConfig | Set-Content $confPath

# 5. Restart aria2 (Kills the process; Task Scheduler will restart it on next login or you can manually start it)
Stop-Process -Name "aria2c" -ErrorAction SilentlyContinue
# Optional: restart immediately if you have the VBS script from the previous step
WScript "$HOME\.config\aria2\Start-Aria2.vbs"

Write-Host "Trackers updated successfully."
