# yazi's plugins and flavors, pinned in yazi/package.toml

@{
    Update = {
        Write-Step 'yazi packages'
        if (-not (Get-Command ya -ErrorAction SilentlyContinue)) { Write-Skip 'yazi not installed'; return }
        # ya writes to %APPDATA%\yazi\config\package.toml, which reaches the repo only through its
        # symlink (symlinks.windows)
        if ((Get-Item "$env:APPDATA\yazi\config\package.toml" -ErrorAction SilentlyContinue).LinkType -ne 'SymbolicLink') {
            Write-Warn "yazi's package.toml isn't the repo's symlink"
            $todo.Add("yazi: swap %APPDATA%\yazi\config\package.toml for the repo's symlink (delete it, then setup_symlinks.ps1, section 7), then ya pkg upgrade")
            return
        }
        # A bump pulled from another machine changes package.toml's hashes under the plugins deployed
        # here, so ya takes them for local edits and aborts
        ya pkg upgrade
        if ($LASTEXITCODE) { $todo.Add('ya pkg upgrade failed: if it says you modified a plugin you never touched, package.toml was bumped elsewhere: ya pkg install --discard, then ya pkg upgrade') }
        if (git -C $repo status --porcelain -- yazi/package.toml) { $todo.Add('Commit the new yazi/package.toml revisions') }
    }
}
