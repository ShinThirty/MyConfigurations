# Windows Update. Drivers are excluded by policy (section 5.4), so this is the cumulative update,
# Defender and .NET. Installing takes a restart, so it stays in Settings

@{
    Update = {
        Write-Step 'Windows Update'
        Start-Process 'ms-settings:windowsupdate'
        Write-Host '  Opened Settings > Windows Update: check for updates there while this runs'
        $todo.Add('Windows Update: finish it in Settings, and reboot if it asks')
    }
}
