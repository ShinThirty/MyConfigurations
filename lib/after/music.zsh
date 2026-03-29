# Music player using fzf + mpv + yt-dlp
# Playlists are plain text files in ~/Music/playlists/
# Format: Title | URL (one entry per line, # comments allowed)

if (( $+commands[mpv] )) && (( $+commands[fzf] )) && (( $+commands[yt-dlp] )); then

MUSIC_PLAYLIST_DIR="$HOME/Music/playlists"
MUSIC_MPV_SOCKET="/tmp/mpv-music"

_mpv_ipc() {
    python3 -c "
import socket, json, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    s.connect('$MUSIC_MPV_SOCKET')
    s.sendall((json.dumps({'command': json.loads(sys.argv[1])}) + '\n').encode())
    resp = s.recv(4096).decode().strip()
    if resp:
        data = json.loads(resp)
        if 'data' in data and data['data'] is not None:
            print(data['data'])
except (ConnectionRefusedError, FileNotFoundError, OSError):
    print('mpv is not running', file=sys.stderr)
    sys.exit(1)
finally:
    s.close()
" "$1"
}

music() {
    [[ -d "$MUSIC_PLAYLIST_DIR" ]] || mkdir -p "$MUSIC_PLAYLIST_DIR"

    case "$1" in
        add)
            if [[ -z "$2" || -z "$3" ]]; then
                printf '\033[33mUsage: music add <playlist> <url>\033[0m\n'
                return 1
            fi
            local file="$MUSIC_PLAYLIST_DIR/$2.txt"
            printf '\033[33mResolving title...\033[0m\n'
            local title
            title=$(yt-dlp --get-title "$3" 2>/dev/null)
            [[ -z "$title" ]] && title="$3"
            local entry="$title | $3"
            echo "$entry" >> "$file"
            printf '\033[32mAdded: %s\033[0m\n' "$entry"
            ;;
        list)
            local playlists=("$MUSIC_PLAYLIST_DIR"/*.txt(N))
            if [[ ${#playlists[@]} -eq 0 ]]; then
                printf '\033[33mNo playlists in %s\033[0m\n' "$MUSIC_PLAYLIST_DIR"
                return 1
            fi
            for f in "${playlists[@]}"; do
                local name="${f:t:r}"
                local count=$(grep -cv '^\s*#\|^\s*$' "$f" 2>/dev/null || echo 0)
                printf '\033[32m%s\033[0m (%d tracks)\n' "$name" "$count"
            done
            ;;
        import)
            if [[ -z "$2" || -z "$3" ]]; then
                printf '\033[33mUsage: music import <playlist> <playlist-url>\033[0m\n'
                return 1
            fi
            local file="$MUSIC_PLAYLIST_DIR/$2.txt"
            printf '\033[33mFetching playlist...\033[0m\n'
            local tracks
            tracks=$(yt-dlp --flat-playlist --print '%(title)s | %(url)s' "$3" 2>/dev/null)
            if [[ -z "$tracks" ]]; then
                printf '\033[31mFailed to fetch playlist\033[0m\n'
                return 1
            fi
            echo "$tracks" >> "$file"
            local count=$(echo "$tracks" | wc -l | tr -d ' ')
            printf '\033[32mImported %s track(s) to %s\033[0m\n' "$count" "$2"
            ;;
        rm)
            if [[ -z "$2" ]]; then
                printf '\033[33mUsage: music rm <playlist>\033[0m\n'
                return 1
            fi
            local file="$MUSIC_PLAYLIST_DIR/$2.txt"
            if [[ ! -f "$file" ]]; then
                printf '\033[31mPlaylist not found: %s\033[0m\n' "$2"
                return 1
            fi
            local selected
            selected=$(grep -v '^\s*#\|^\s*$' "$file" | fzf --prompt="Remove> " --multi)
            [[ -z "$selected" ]] && return
            local tmpfile=$(mktemp)
            while IFS= read -r line; do
                if [[ -z "$line" || "$line" =~ '^\s*#' ]]; then
                    echo "$line" >> "$tmpfile"
                    continue
                fi
                echo "$selected" | grep -qxF "$line" || echo "$line" >> "$tmpfile"
            done < "$file"
            mv "$tmpfile" "$file"
            local count=$(echo "$selected" | wc -l | tr -d ' ')
            printf '\033[32mRemoved %s track(s)\033[0m\n' "$count"
            ;;
        stop)
            _mpv_ipc '["quit"]'
            ;;
        pause)
            _mpv_ipc '["cycle", "pause"]'
            ;;
        next)
            _mpv_ipc '["playlist-next"]'
            ;;
        prev)
            _mpv_ipc '["playlist-prev"]'
            ;;
        status)
            local title
            title=$(_mpv_ipc '["get_property", "media-title"]' 2>/dev/null)
            if [[ -n "$title" ]]; then
                local paused
                paused=$(_mpv_ipc '["get_property", "pause"]' 2>/dev/null)
                local state="Playing"
                [[ "$paused" == "True" ]] && state="Paused"
                printf '\033[32m%s\033[0m: %s\n' "$state" "$title"
            else
                printf '\033[33mmpv is not running\033[0m\n'
            fi
            ;;
        *)
            local playlists=("$MUSIC_PLAYLIST_DIR"/*.txt(N))
            if [[ ${#playlists[@]} -eq 0 ]]; then
                printf '\033[33mNo playlists in %s\033[0m\n' "$MUSIC_PLAYLIST_DIR"
                return 1
            fi

            local selected_file
            if [[ -n "$1" ]]; then
                selected_file="$MUSIC_PLAYLIST_DIR/$1.txt"
                if [[ ! -f "$selected_file" ]]; then
                    printf '\033[31mPlaylist not found: %s\033[0m\n' "$1"
                    return 1
                fi
            else
                local name
                name=$(printf '%s\n' "${playlists[@]:t:r}" | fzf --prompt="Playlist> ")
                [[ -z "$name" ]] && return
                selected_file="$MUSIC_PLAYLIST_DIR/$name.txt"
            fi

            local entries
            entries=$(grep -v '^\s*#\|^\s*$' "$selected_file")
            if [[ -z "$entries" ]]; then
                printf '\033[33mPlaylist is empty\033[0m\n'
                return 1
            fi

            local choice
            choice=$(printf '%s\n%s' ">> Play All
>> Shuffle All" "$entries" | fzf --prompt="Track> " --multi)
            [[ -z "$choice" ]] && return

            local urls=()
            local shuffle=false

            if echo "$choice" | grep -qxF ">> Shuffle All"; then
                shuffle=true
                while IFS= read -r line; do
                    urls+=("${line##*| }")
                done <<< "$entries"
            elif echo "$choice" | grep -qxF ">> Play All"; then
                while IFS= read -r line; do
                    urls+=("${line##*| }")
                done <<< "$entries"
            else
                while IFS= read -r line; do
                    urls+=("${line##*| }")
                done <<< "$choice"
            fi

            # Stop any existing mpv instance
            _mpv_ipc '["quit"]' 2>/dev/null
            sleep 0.3

            local mpv_args=(--no-video "--input-ipc-server=$MUSIC_MPV_SOCKET")
            if $shuffle; then mpv_args+=(--shuffle); fi
            mpv "${mpv_args[@]}" "${urls[@]}" &!
            ;;
    esac
}

fi
