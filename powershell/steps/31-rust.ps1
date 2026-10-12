# The Rust toolchain

@{
    Update = {
        Write-Step 'Rust toolchain'
        if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) { Write-Skip 'rustup not installed'; return }
        rustup update
        if ($LASTEXITCODE) { $todo.Add('rustup update failed: read its output above') }
    }
}
