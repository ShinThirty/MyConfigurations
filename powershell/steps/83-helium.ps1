# Helium's new tab links, in ~\.config\helium-newtab\links.js, against the sites its history says you
# open: helium\newtab-links.ps1 lists the sites to add a link for and the links to drop

@{
    Update = {
        Write-Step "Helium's new tab"
        if (-not (Test-Path "$HOME\scoop\apps\helium")) { Write-Skip 'not installed'; return }
        try {
            $lines = @(& "$repo\helium\newtab-links.ps1")
        } catch {
            Write-Warn "couldn't read Helium's history: $_"
            return
        }
        if ($lines) {
            Write-Warn 'links to add or drop, listed below'
            $lines | ForEach-Object { $todo.Add("Helium's new tab: $_") }
        } else {
            Write-Ok 'its links are the sites you open'
        }
    }
}
