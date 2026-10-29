# What a Windows update can quietly reset: the section 5 settings, Helium's policies and link
# handlers, the Run entries apps put back, and the firewall and Defender (SECURITY.md)

@{
    Update = {
        Write-Step 'Settings'
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft'
        $expected = [ordered]@{
            # 5.1
            'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' = @{ RealTimeIsUniversal = 1 }
            'HKLM:\SYSTEM\CurrentControlSet\Control\Power' = @{ HibernateEnabled = 0 }
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' = @{ HiberbootEnabled = 0 }
            'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' = @{ LongPathsEnabled = 1 }
            # sudo config --enable disableInput
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' = @{ Enabled = 2 }
            # 5.2
            'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' = @{ 'Scancode Map' = '00000000000000000300000001003A003A00010000000000' }
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' = @{ AppsUseLightTheme = 0; SystemUsesLightTheme = 0 }
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' = @{ '{645FF040-5081-101B-9F08-00AA002F954E}' = 1 }
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' = @{ HideFileExt = 0 }
            'HKCU:\Control Panel\Mouse' = @{ MouseSpeed = '0'; MouseThreshold1 = '0'; MouseThreshold2 = '0' }
            'HKCU:\Control Panel\Keyboard' = @{ KeyboardDelay = '0'; InitialKeyboardIndicators = '2' }
            'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' = @{ InitialKeyboardIndicators = '2147483650' }
            'HKCU:\Control Panel\Accessibility\StickyKeys' = @{ Flags = '506' }
            # 5.3
            "$p\Windows\DataCollection" = @{ AllowTelemetry = 0; DoNotShowFeedbackNotifications = 1 }
            "$p\Windows\Windows Error Reporting" = @{ Disabled = 1 }
            "$p\Windows\AdvertisingInfo" = @{ DisabledByGroupPolicy = 1 }
            "$p\Windows\System" = @{ PublishUserActivities = 0; UploadUserActivities = 0 }
            "$p\Windows\CloudContent" = @{ DisableWindowsConsumerFeatures = 1 }
            'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' = @{ DisableTailoredExperiencesWithDiagnosticData = 1 }
            'HKCU:\Software\Policies\Microsoft\Windows\Explorer' = @{ DisableSearchBoxSuggestions = 1 }
            # 5.3 and 5.5
            "$p\Edge" = @{ DiagnosticData = 0; StartupBoostEnabled = 0; BackgroundModeEnabled = 0 }
            # 5.4
            "$p\Windows\WindowsUpdate" = @{ ExcludeWUDriversInQualityUpdate = 1 }
            # 5.5
            'HKCU:\System\GameConfigStore' = @{ GameDVR_Enabled = 0 }
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' = @{ AppCaptureEnabled = 0 }
            "$p\Windows\GameDVR" = @{ AllowGameDVR = 0 }
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{
                SoftLandingEnabled = 0; 'SubscribedContent-338389Enabled' = 0; SystemPaneSuggestionsEnabled = 0
                'SubscribedContent-310093Enabled' = 0; 'SubscribedContent-338387Enabled' = 0; RotatingLockScreenOverlayEnabled = 0
            }
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' = @{ ScoobeSystemSettingEnabled = 0 }
        }
        $drift = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $expected.Keys) {
            $actual = Get-ItemProperty $key -ErrorAction SilentlyContinue
            foreach ($name in $expected[$key].Keys) {
                $want = $expected[$key][$name]
                $value = $actual.$name
                if ($value -is [byte[]]) { $value = [Convert]::ToHexString($value) }
                if ($value -ne $want) { $drift.Add("$key\$name is $($value ?? 'missing'), expected $want (section 5)") }
            }
        }
        if ((Get-Service DiagTrack).StartType -ne 'Disabled') { $drift.Add('the DiagTrack service is no longer disabled (section 5.3)') }
        if ([Environment]::GetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'User') -ne '1') {
            $drift.Add('POWERSHELL_TELEMETRY_OPTOUT is no longer set (section 5.3)')
        }
        if (Test-Path "$HOME\scoop\apps\helium") {
            & "$repo\helium\apply-policies.ps1" -Check | ForEach-Object { $drift.Add("Helium's policy $_ (rerun helium\apply-policies.ps1 elevated, section 12.1)") }
            & "$repo\helium\fix-handlers.ps1" -Check | ForEach-Object { $drift.Add("$_ opens Helium without its profile folder (rerun helium\fix-handlers.ps1, section 12.1)") }
        }
        $tips = @(Get-ScheduledTask -TaskPath '\SoftLanding\*' -ErrorAction SilentlyContinue | Where-Object State -ne 'Disabled')
        if ($tips) { $drift.Add("$($tips.Count) \SoftLanding\ tip tasks are enabled (section 5.5)") }
        $runNames = 'HKCU:', 'HKLM:' | ForEach-Object { (Get-Item "$_\Software\Microsoft\Windows\CurrentVersion\Run").GetValueNames() }
        $unwanted = [ordered]@{ 'Logitech Download Assistant' = '5.4'; 'MicrosoftEdgeAutoLaunch_*' = '5.5' }
        foreach ($pattern in $unwanted.Keys) {
            $runNames | Where-Object { $_ -like $pattern } | ForEach-Object { $drift.Add("the Run key has $_ again (section $($unwanted[$pattern]))") }
        }
        if ($drift) {
            Write-Warn "$($drift.Count) changed, listed below"
            $drift | ForEach-Object { $todo.Add("Reset: $_") }
        } else {
            Write-Ok 'all as set'
        }

        # SECURITY.md sections 2 and 4. Defender's status is missing when another antivirus replaced it.
        $insecure = [System.Collections.Generic.List[string]]::new()
        Get-NetFirewallProfile | Where-Object Enabled -eq 'False' | ForEach-Object {
            $insecure.Add("the firewall is off for $($_.Name) networks: Windows Security > Firewall & network protection (SECURITY.md section 2)")
        }
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($defender -and -not $defender.RealTimeProtectionEnabled) {
            $insecure.Add("Defender's real-time protection is off: Windows Security > Virus & threat protection (SECURITY.md section 4)")
        }
        if ($insecure) {
            Write-Warn "$($insecure.Count) of SECURITY.md's settings not as it says, listed below"
            $insecure | ForEach-Object { $todo.Add("Security: $_") }
        } else {
            Write-Ok "the firewall and Defender are on"
        }
    }
}
