<#
Merges preferences.json, then preferences.windows.json, into Helium's Default profile: the Windows
counterpart of apply-preferences.sh. None of these settings has a policy, so they live in the
profile's own Preferences file, which Helium rewrites on exit; close it first. Keys the fragments
don't name are left alone, so rerunning is harmless. The previous file is kept as Preferences.bak.

  preferences.json          every platform: Helium's layout and zen mode, the profile's name and
                            avatar
  preferences.windows.json  the page languages, Edge's. The fonts stay Chromium's defaults, as they
                            were in Edge. The search engine is a signed setting, which Windows resets
                            when it's edited in the file, so Google is set in Helium's settings

scoop's Helium keeps its profile in ~\scoop\persist\helium\User Data; -UserData points the script at
a copy.

To record a setting changed in Helium's settings, diff Preferences from before the change and after
Helium closes.
#>
param([string]$UserData = "$HOME\scoop\persist\helium\User Data")
$ErrorActionPreference = 'Stop'

$prefs = "$UserData\Default\Preferences"
if (-not (Test-Path $prefs)) { throw "No profile at $prefs yet: start Helium once, then close it" }
# The process is chrome.exe, so it's Helium only when it runs from scoop's helium folder
if (Get-Process chrome -ErrorAction SilentlyContinue | Where-Object Path -like '*\scoop\apps\helium\*') {
    throw 'Helium is running and would overwrite the merge on exit; close it first'
}

# jq -a escapes everything outside ASCII, so the console's encoding can't garble what it writes
function Set-Json($path, [string[]]$jqArgs) {
    $json = jq -a -c @jqArgs
    if ($LASTEXITCODE) { throw "jq couldn't rewrite $path" }
    Copy-Item $path "$path.bak"
    Set-Content "$path.tmp" $json -NoNewline
    Move-Item -Force "$path.tmp" $path
}

Set-Json $prefs '-s', '.[0] * .[1] * .[2]', $prefs, "$PSScriptRoot\preferences.json", "$PSScriptRoot\preferences.windows.json"
Write-Host "Merged preferences.json and preferences.windows.json into $($prefs.Replace($HOME, '~'))"

# The profile menu shows the name and avatar from Local State's profile cache, which Helium doesn't
# refresh from Preferences on its own.
$state = "$UserData\Local State"
Set-Json $state '--slurpfile', 'f', "$PSScriptRoot\preferences.json", @'
  ($f[0].profile // {}) as $p
  | if $p.name then
      .profile.info_cache.Default += {name: $p.name, is_using_default_name: false}
    else . end
  | if $p.avatar_index then
      .profile.info_cache.Default += {
        avatar_icon: "chrome://theme/IDR_PROFILE_AVATAR_\($p.avatar_index)",
        is_using_default_avatar: false
      }
    else . end
'@, $state
Write-Host "Set the profile's name and avatar in $($state.Replace($HOME, '~'))"
