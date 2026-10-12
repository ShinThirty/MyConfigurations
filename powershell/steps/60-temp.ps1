# Your TEMP folder: files a week old, then the folders that leaves empty

@{
    Cleanup = {
        $tempDays = 7
        Write-Step "Cleanup: TEMP files older than $tempDays days"
        $cutoff = (Get-Date).AddDays(-$tempDays)
        $count = 0; $bytes = 0; $inUse = 0
        # pwsh doesn't recurse into links, so a junction in TEMP can't lead this anywhere else
        Get-ChildItem $env:TEMP -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff | ForEach-Object {
            $size = $_.Length
            try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; $count++; $bytes += $size } catch { $inUse++ }
        }
        # Then the folders that leaves empty, deepest first. By creation date, since deleting a folder's
        # files moves its modified date. Directory.Delete refuses a folder that isn't empty, where
        # Remove-Item would ask to delete its contents
        Get-ChildItem $env:TEMP -Recurse -Force -Directory -Attributes !ReparsePoint -ErrorAction SilentlyContinue |
            Where-Object CreationTime -lt $cutoff | Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object { try { [IO.Directory]::Delete($_.FullName) } catch {} }
        Write-Host ('  Deleted {0} files, {1:N0} MB' -f $count, ($bytes / 1MB))
        if ($inUse) { Write-Skip "$inUse in use, so left for next month" }
    }
}
