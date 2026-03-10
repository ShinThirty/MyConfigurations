# aria2 Configuration

High-performance [aria2](https://github.com/aria2/aria2) setup with automatic tracker updates and background daemon across macOS, Linux, and Windows.

## Directory Structure

```
aria2/
├── aria2.conf                  # Shared config (all platforms)
├── aria2_update_tracker.sh     # Tracker updater script (macOS + Linux)
├── darwin/                     # macOS: launchd plists + install script
├── linux/                      # Linux: systemd units + install script
└── windows/                    # Windows: VBS launchers, PS1 scripts + install
```

## Shared Configuration

`aria2.conf` is the universal config used by all platforms. Key settings:

- **RPC** enabled on port 6800 (for frontends like AriaNg)
- **16 connections** per server, **32-way split** for parallel downloads
- **Session persistence** — downloads survive restarts via `aria2.session`
- **BitTorrent** — DHT, PEX, and seeding up to 1:1 ratio
- **Disk** — `falloc` pre-allocation (ext4/NTFS)

## Installation

### macOS

```bash
brew install aria2
cd darwin && bash install.sh
```

This copies the config and session file to `$XDG_CONFIG_HOME/aria2/`, and installs two Launch Agents:

- `com.aria2.plist` — runs aria2 at login
- `com.aria2.regular.tracker.update.plist` — periodic tracker updates

Load them with:

```bash
launchctl load ~/Library/LaunchAgents/com.aria2.plist
launchctl load ~/Library/LaunchAgents/com.aria2.regular.tracker.update.plist
```

### Arch Linux

```bash
sudo pacman -S aria2
cd linux && bash install.sh
```

This copies the config and session file to `$XDG_CONFIG_HOME/aria2/`, and installs systemd user units:

- `aria2.service` — runs aria2 as a user service
- `aria2_update_tracker.service` + `aria2_update_tracker.timer` — periodic tracker updates

Enable them with:

```bash
systemctl --user enable --now aria2.service
systemctl --user enable --now aria2_update_tracker.timer
```

### Windows

```powershell
winget install aria2
cd windows
.\install.ps1
```

This copies the config, session file, VBS launchers, and PowerShell scripts to `$HOME\.config\aria2\`.

To run aria2 at login, create a Task Scheduler task:

1. **General**: Name it "Aria2", select "Run only when user is logged on"
2. **Triggers**: New -> "At log on"
3. **Actions**: New -> Start a program -> `wscript.exe`
   - Add arguments: `%USERPROFILE%\.config\aria2\Start-Aria2.vbs`

To schedule automatic tracker updates, create another task:

1. **Triggers**: Weekly (or preferred interval)
2. **Actions**: Start a program -> `wscript.exe`
   - Add arguments: `%USERPROFILE%\.config\aria2\Update-Trackers.vbs`

#### Firewall Rules

To allow incoming BitTorrent connections (ports 6881-6999), run as Administrator:

```powershell
.\add_firewall_rules.ps1
```

## Tracker Updates

aria2 doesn't update BitTorrent trackers automatically. The tracker update scripts fetch the [best tracker list](https://github.com/ngosang/trackerslist) and inject it into `aria2.conf` as a comma-separated `bt-tracker=` line, then restart the daemon.

- **macOS/Linux**: `aria2_update_tracker.sh` (handled by launchd/systemd)
- **Windows**: `windows/update_trackers.ps1` (handled by Task Scheduler)

## Frontend

Use [AriaNg](https://github.com/mayswind/AriaNg) as a web frontend to manage downloads via the RPC interface. Browser extensions for automatic download interception:

- **Chrome/Edge/Brave**: [Aria2 Explorer](https://chromewebstore.google.com/detail/aria2-explorer/mpkodccbngfoacfalldjimigbofkhgjn) — built-in AriaNg, smart interception, user-agent spoofing
- **Firefox**: [Aria2 Integration](https://addons.mozilla.org/en-US/firefox/addon/aria2-integration/) — equivalent feature set for Firefox

Configure the extension with RPC URL `http://localhost:6800/jsonrpc` and enable download capture.

## CLI Cheat Sheet

| Flag | Description |
|------|-------------|
| `-x16` | Max connections per server (default 1, sweet spot: 16) |
| `-s16` | Split file into N pieces (usually match `-x`) |
| `-c` | Resume an interrupted download |
| `-d <path>` | Save to a specific directory |
| `-o <name>` | Rename the output file |
| `-i <file>` | Read URLs from a text file (batch download) |
| `-j <N>` | Concurrent downloads (for batch files) |
| `--no-conf` | Ignore global `aria2.conf` (prevents port conflicts with daemon) |

Common examples:

```bash
# Fast HTTP download
aria2c -x16 -s16 -k1M "https://example.com/file.iso"

# Download a magnet link (must quote the URL)
aria2c "magnet:?xt=urn:btih:..."

# Selective torrent download — list files first, then pick
aria2c -S "/path/to/file.torrent"
aria2c --select-file=1,4,5 "/path/to/file.torrent"

# Batch download from a file with 5 concurrent jobs
aria2c -i links.txt -j 5

# Resume a broken download
aria2c -c "https://example.com/large_file.zip"
```
