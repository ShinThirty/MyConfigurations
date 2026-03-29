# Music player using fzf + mpv + yt-dlp
# Playlists are plain text files in ~/Music/playlists/
# Format: Title | URL (one entry per line, # comments allowed)
# IPC: mpv listens on \\.\pipe\mpv-music for playback control

$global:MusicPlaylistDir = "$HOME\Music\playlists"
$global:MusicMpvPipe = 'mpv-music'

function _Send-MpvCommand
{
    param([string]$JsonCmd)
    try
    {
        $pipe = [System.IO.Pipes.NamedPipeClientStream]::new('.', $global:MusicMpvPipe, [System.IO.Pipes.PipeDirection]::InOut)
        $pipe.Connect(1000)
        $writer = [System.IO.StreamWriter]::new($pipe)
        $reader = [System.IO.StreamReader]::new($pipe)
        $writer.AutoFlush = $true
        $writer.WriteLine($JsonCmd)
        $response = $reader.ReadLine()
        $pipe.Close()
        return $response
    }
    catch
    {
        Write-Host "mpv is not running" -ForegroundColor Yellow
        return $null
    }
}

function music
{
    param(
        [string]$Command,
        [string]$Arg1,
        [string]$Arg2
    )

    if (-not (Test-Path $global:MusicPlaylistDir))
    {
        New-Item -ItemType Directory -Path $global:MusicPlaylistDir -Force | Out-Null
    }

    switch ($Command)
    {
        'add' {
            if (-not $Arg1 -or -not $Arg2)
            {
                Write-Host "Usage: music add <playlist> <url>" -ForegroundColor Yellow
                return
            }
            $file = "$global:MusicPlaylistDir\$Arg1.txt"
            Write-Host "Resolving title..." -ForegroundColor Yellow
            $title = & yt-dlp --get-title $Arg2 2>$null
            if (-not $title) { $title = $Arg2 }
            $entry = "$title | $Arg2"
            Add-Content -Path $file -Value $entry
            Write-Host "Added: $entry" -ForegroundColor Green
        }
        'list' {
            $playlists = Get-ChildItem "$global:MusicPlaylistDir\*.txt" -ErrorAction SilentlyContinue
            if (-not $playlists)
            {
                Write-Host "No playlists in $global:MusicPlaylistDir" -ForegroundColor Yellow
                return
            }
            $playlists | ForEach-Object {
                $count = (Get-Content $_.FullName | Where-Object { $_ -and -not $_.StartsWith('#') }).Count
                Write-Host "$($_.BaseName)" -ForegroundColor Green -NoNewline
                Write-Host " ($count tracks)"
            }
        }
        'import' {
            if (-not $Arg1 -or -not $Arg2)
            {
                Write-Host "Usage: music import <playlist> <playlist-url>" -ForegroundColor Yellow
                return
            }
            $file = "$global:MusicPlaylistDir\$Arg1.txt"
            Write-Host "Fetching playlist..." -ForegroundColor Yellow
            $tracks = & yt-dlp --flat-playlist --print '%(title)s | %(url)s' $Arg2 2>$null
            if (-not $tracks)
            {
                Write-Host "Failed to fetch playlist" -ForegroundColor Red
                return
            }
            $tracks | Add-Content -Path $file
            $count = @($tracks).Count
            Write-Host "Imported $count track(s) to $Arg1" -ForegroundColor Green
        }
        'rm' {
            if (-not $Arg1)
            {
                Write-Host "Usage: music rm <playlist>" -ForegroundColor Yellow
                return
            }
            $file = "$global:MusicPlaylistDir\$Arg1.txt"
            if (-not (Test-Path $file))
            {
                Write-Host "Playlist not found: $Arg1" -ForegroundColor Red
                return
            }
            $entries = Get-Content $file | Where-Object { $_ -and -not $_.StartsWith('#') }
            $selected = $entries | fzf --prompt="Remove> " --multi
            if (-not $selected) { return }
            $remaining = $entries | Where-Object { $selected -notcontains $_ }
            if ($remaining)
            {
                Set-Content -Path $file -Value $remaining
            }
            else
            {
                Clear-Content -Path $file
            }
            $count = @($selected).Count
            Write-Host "Removed $count track(s)" -ForegroundColor Green
        }
        'stop' {
            _Send-MpvCommand '{"command": ["quit"]}' | Out-Null
        }
        'pause' {
            _Send-MpvCommand '{"command": ["cycle", "pause"]}' | Out-Null
        }
        'next' {
            _Send-MpvCommand '{"command": ["playlist-next"]}' | Out-Null
        }
        'prev' {
            _Send-MpvCommand '{"command": ["playlist-prev"]}' | Out-Null
        }
        'status' {
            $resp = _Send-MpvCommand '{"command": ["get_property", "media-title"]}'
            if ($resp)
            {
                $data = $resp | ConvertFrom-Json
                $title = $data.data
                $pauseResp = _Send-MpvCommand '{"command": ["get_property", "pause"]}' | ConvertFrom-Json
                $state = if ($pauseResp.data) { "Paused" } else { "Playing" }
                Write-Host "$state" -ForegroundColor Green -NoNewline
                Write-Host ": $title"
            }
        }
        default {
            $playlists = Get-ChildItem "$global:MusicPlaylistDir\*.txt" -ErrorAction SilentlyContinue
            if (-not $playlists)
            {
                Write-Host "No playlists in $global:MusicPlaylistDir" -ForegroundColor Yellow
                return
            }

            # Direct playlist name or fzf select
            if ($Command)
            {
                $selectedFile = "$global:MusicPlaylistDir\$Command.txt"
                if (-not (Test-Path $selectedFile))
                {
                    Write-Host "Playlist not found: $Command" -ForegroundColor Red
                    return
                }
            }
            else
            {
                $selected = $playlists | ForEach-Object { $_.BaseName } | fzf --prompt="Playlist> "
                if (-not $selected) { return }
                $selectedFile = "$global:MusicPlaylistDir\$selected.txt"
            }

            $entries = Get-Content $selectedFile | Where-Object { $_ -and -not $_.StartsWith('#') }
            if (-not $entries)
            {
                Write-Host "Playlist is empty" -ForegroundColor Yellow
                return
            }

            $choice = @(">> Play All", ">> Shuffle All") + $entries | fzf --prompt="Track> " --multi
            if (-not $choice) { return }

            $shuffle = $false
            $source = @($choice)
            if ($choice -contains ">> Shuffle All")
            {
                $source = $entries
                $shuffle = $true
            }
            elseif ($choice -contains ">> Play All")
            {
                $source = $entries
            }
            $urls = $source | ForEach-Object { ($_ -split '\|', 2)[-1].Trim() }

            # Stop any existing mpv instance
            _Send-MpvCommand '{"command": ["quit"]}' 2>$null | Out-Null
            Start-Sleep -Milliseconds 300

            $mpvArgs = @('--no-video', "--input-ipc-server=\\.\pipe\$global:MusicMpvPipe")
            if ($shuffle) { $mpvArgs += '--shuffle' }
            $mpvArgs += $urls
            Start-Process mpv -ArgumentList $mpvArgs -WindowStyle Hidden
        }
    }
}
