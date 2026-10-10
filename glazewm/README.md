# GlazeWM -- Hyprland-like tiling on Windows

Tiling window manager setup for Windows, replicating core Hyprland functionality with gruvbox dark hard theme.

## Install

```powershell
# Core
scoop bucket add extras
scoop install extras/glazewm
scoop install extras/zebar
scoop install extras/flow-launcher
scoop install extras/sharex

# Music
scoop install mpv
scoop install yt-dlp

# Flow Launcher Music plugin dependency
cd "$HOME\scoop\persist\flow-launcher\UserData\Plugins\Music"
pip install -r requirements.txt -t lib
```

Then link the config:

```powershell
.\setup_symlinks.ps1
```

### Post-install

- Right-click GlazeWM tray icon -> **Run on system startup**
- Change Flow Launcher hotkey to `ctrl+space` (default `alt+space` conflicts with GlazeWM)
- Enable clipboard history: press `Win+V` and follow the prompt
- ShareX: Application settings → Integration → **Run ShareX when Windows starts**, and
  Task settings → After capture: **Copy image to clipboard** + **Save image to file** only
  (a fresh install also uploads every capture to Imgur). Its config lives in
  `~\scoop\persist\sharex\ShareX\`, so restoring that folder covers both. Then
  check **Hotkey settings** against the table in [Screenshots](#screenshots-sharex)
  — the config isn't tracked here, so a restored backup can carry older bindings

## Components

| Hyprland | Windows | Purpose |
|---|---|---|
| Hyprland | **GlazeWM** | Tiling window manager |
| waybar | **Zebar** | Status bar |
| rofi | **Flow Launcher** | App launcher |
| grim + slurp | **ShareX** | Screenshots and screen recording |
| cliphist | `Win+V` (built-in) | Clipboard history |
| swww | **Lively Wallpaper** (optional) | Animated wallpapers |
| rofi-beats | **Flow Launcher Music plugin** + mpv | Music player |
| cava | -- | Audio visualizer (no good Windows port) |

## Keybindings

Alt is the primary modifier (replaces Super on Hyprland). Use `alt+shift+p` to pause all WM bindings when you need native Alt shortcuts.

### Window management

| Action | Binding |
|---|---|
| Focus window | `alt + h/j/k/l` |
| Move window | `alt+shift + h/j/k/l` |
| Resize window | `alt+ctrl + h/j/k/l` |
| Fullscreen | `alt + f` |
| Float/tile toggle | `alt + v` |
| Close window | `alt + q` |
| Minimize | `alt + m` |
| Toggle split direction | `alt + d` |
| Cycle focus (tiling/float/full) | `alt + space` |

### Workspaces

| Action | Binding |
|---|---|
| Switch workspace | `alt + 1-9` |
| Move window to workspace | `alt+shift + 1-9` |
| Move workspace to monitor | `alt+shift + left/right` |

### Binding modes

| Action | Binding |
|---|---|
| Enter resize mode | `alt + r` |
| Enter move mode | `alt+shift + m` |
| Exit mode | `escape` or `enter` |

In resize/move mode, use `h/j/k/l` or arrow keys to resize/move the focused window.

### Launcher and WM

| Action | Binding |
|---|---|
| Launch terminal | `alt + enter` |
| Reload config | `alt+shift + r` |
| Redraw windows | `alt+shift + w` |
| Pause WM bindings | `alt+shift + p` |
| Exit GlazeWM | `alt+shift + e` |

## Zebar (status bar)

GlazeWM v3 uses [Zebar](https://github.com/glzr-io/zebar) as a companion status bar. The GlazeWM config auto-starts and stops Zebar.

Widget packs live in `~/.glzr/zebar/`. The default pack works out of the box. Customize via the system tray GUI or edit the HTML/CSS/JS files directly.

Available data providers: CPU, memory, battery, network, date/time, media, GlazeWM workspaces, weather.

## Music (mpv + yt-dlp)

Playlists are plain text files in `~/Music/playlists/` with `Title | URL` format.

**Flow Launcher plugin** (keyword `m`): type `m` to see playback controls (when playing) and playlists, `m lofi` to browse tracks, `m lofi rock` to search within a playlist. See `flow-launcher/Music/`.

**Terminal** (PowerShell `powershell/music.ps1`, zsh `lib/after/music.zsh`):

```
music                        # fzf-select playlist, then pick tracks or play/shuffle all
music lofi                   # play a playlist by name
music add lofi <url>         # resolve title via yt-dlp and append
music import lofi <url>      # import all tracks from a playlist URL
music rm lofi                # fzf-select tracks to remove
music list                   # show playlists with track counts
music pause                  # toggle pause/resume
music next / prev            # skip track
music stop                   # stop playback
music status                 # show current track
```

Playback control uses mpv's IPC socket (`/tmp/mpv-music` on macOS/Linux, `\\.\pipe\mpv-music` on Windows).

## Screenshots (ShareX)

ShareX replaces Snipping Tool (LTSC only ships the old one). The keyboard (Keychron
Q7, 70%) has no Print Screen key, so the hotkeys are `ctrl+shift+alt` plus a number,
after macOS's ⌘⇧3/4/5:

| Action | Binding |
|---|---|
| Capture entire screen | `ctrl+shift+alt + 3` |
| Capture region | `ctrl+shift+alt + 4` |
| Start/stop screen recording | `ctrl+shift+alt + 5` |
| Start/stop GIF recording | `ctrl+shift+alt + 6` |
| Capture active window | `ctrl+shift+alt + w` |

Nothing else here uses those: Windows Terminal takes `ctrl+shift` + 1–5/S/T/HJKL and
`ctrl+shift+alt` + HJKL, GlazeWM takes `alt`, and JetBrains IDEs take most of
`ctrl+alt`. ShareX's hotkeys are global, so a clash silently steals the key from the
other app — the old install's `ctrl+shift+s` for active window disabled Windows
Terminal's split-pane-down. They're stored in `HotkeysConfig.json`; quit ShareX
before editing it, since ShareX rewrites it on exit.

Captures go to the clipboard and to `~\scoop\persist\sharex\ShareX\Screenshots\`.

GlazeWM ignores every ShareX window (`window_process: ShareX` in the ignore rule) so the
full-screen region overlay isn't tiled.

## Limitations

- No smooth window animations (GlazeWM has basic ones, not Hyprland-level)
- No window blur or rounded corners
- No per-app opacity rules (only focused vs unfocused)
- Flow Launcher replaces rofi but lacks rofi's scripting flexibility
