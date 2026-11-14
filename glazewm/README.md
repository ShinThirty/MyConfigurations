# GlazeWM -- Hyprland-like tiling on Windows

Tiling window manager setup for Windows, replicating core Hyprland functionality with gruvbox dark hard theme.

## Install

```powershell
# Core
scoop bucket add extras
scoop install extras/glazewm
scoop install extras/sharex

# Music
scoop install mpv
scoop install yt-dlp
```

Then link the config:

```powershell
.\setup_symlinks.ps1
```

And build the workspace number's tray icon ([Status bar](#status-bar-taskbar)):

```powershell
.\glazewm\build-workspace-tray.ps1
```

### Post-install

- Right-click GlazeWM tray icon -> **Run on system startup**
- Settings → Personalization → Taskbar → Taskbar behaviors → **Taskbar position: Top**, and
  Other system tray icons → **GlazeWM workspace** on ([Status bar](#status-bar-taskbar))
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
| waybar | Taskbar (built-in) at the top, and **workspace-tray** | Status bar |
| rofi | Start menu (built-in) | App launcher |
| grim + slurp | **ShareX** | Screenshots and screen recording |
| cliphist | `Win+V` (built-in) | Clipboard history |
| swww | **Lively Wallpaper** (optional) | Animated wallpapers |
| rofi-beats | `music` (PowerShell) + mpv | Music player |
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

## Status bar (taskbar)

The Windows taskbar is the status bar, at the top of the screen: Settings → Personalization →
Taskbar → Taskbar behaviors → **Taskbar position: Top**. Moving it there turns auto-hide off, and it
stays off, so the taskbar is always visible. GlazeWM tiles windows below it, with the same 8px gap as
the other edges.

With `show_all_in_taskbar: false` and `hide_method: 'cloak'`, the taskbar shows only the current
workspace's windows.

The focused workspace's number is a tray icon, drawn in Gruvbox fg by `workspace-tray.cs`: a small
C# program that listens on GlazeWM's socket (127.0.0.1:6123) and redraws the icon when focus
changes. It uses about 25 MB and no CPU between switches. `build-workspace-tray.ps1` builds it, with
the C# compiler in .NET Framework 4.8, which Windows ships, into `%LOCALAPPDATA%\workspace-tray\`,
and gives the exe a hash of the source and the script as its product version. The monthly update
(step 53) rebuilds it when that hash is out of date; rerunning the script applies a change at once.
GlazeWM's startup command starts it, and it exits when GlazeWM does. Windows puts a new tray icon in the overflow: turn it on under Settings → Personalization →
Taskbar → Other system tray icons → **GlazeWM workspace**.

The monthly update's settings step checks both: the position (`TaskbarLocation` is 1 in
`HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`), and that the icon is on the
taskbar (`IsPromoted` is 1 in its key under `HKCU:\Control Panel\NotifyIconSettings`).

## Music (mpv + yt-dlp)

Playlists are plain text files in `~/Music/playlists/` with `Title | URL` format.

From the terminal (PowerShell `powershell/music.ps1`, zsh `lib/after/music.zsh`):

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
- The Start menu launches apps, but can't be scripted like rofi
