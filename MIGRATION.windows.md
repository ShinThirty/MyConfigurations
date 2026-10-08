# Migrating to a new Windows install

Runbook for (re)installing Windows 11 LTSC on the Arch/Windows dual-boot box and
standing this setup back up on it. Unlike macOS and Arch there is no bootstrap
script — the Windows side is a handful of scoop installs plus
`setup_symlinks.ps1` and `powershell/install_modules.ps1`, listed here in order.

Rough order: **back up from Arch → ISO + drivers → install USB → install
Windows → fix the boot order → Windows settings → scoop → repo → SSH keys →
desktop → verify.**

> Scope note: the Windows side of this repo covers PowerShell, git, gitui, nvim,
> yazi, Windows Terminal, GlazeWM, Flow Launcher, aria2 and IdeaVim. Personal
> apps are out of scope.

---

## 1. The dual-boot layout

```
nvme1n1 (Windows disk)
├─p1  512M  EFI System    ← mounted at /boot on Arch: systemd-boot, vmlinuz-linux-zen,
│                            initramfs-linux-zen.img, amd-ucode.img all live HERE
├─p2   16M  MSR
├─p3  249G  NTFS "Corona" ← C:
├─p4  735M  WinRE
└─p5  1.6T  NTFS "Nebula" ← data, survives the reinstall
nvme0n1  → Arch LVM (ArchVG-root, ArchVG-home) — Windows setup never touches it
```

**The ESP is shared.** Arch's kernel lives on the Windows disk, so deleting p1
in Windows setup leaves Arch unbootable even though its root is on the other
drive. The plan is to reuse the existing partition scheme: format and install
into p3 only.

---

## 2. Before you start (from Arch)

```sh
sudo tar -C /boot -czf ~/boot-backup.tgz .   # ~70 MB, lands on nvme0n1, safe
blkid /dev/nvme1n1p1                         # note the UUID — currently 132D-60E4
```

`/etc/fstab` mounts `/boot` by that UUID. If the ESP is ever reformatted the
UUID changes and Arch drops to an emergency shell (see [section 4](#4-restoring-arch-boot)).

From the old Windows, if it still boots:

- Save the **BitLocker recovery key** for any encrypted volume (`manage-bde -status`), or decrypt Nebula first
- Copy anything off C: you want to keep — `~\.ssh`, `~\Music\playlists`, `~\.config\aria2\aria2.session`, browser profiles
- Note Nebula's drive letter; apps and shortcuts that point into it depend on it

---

## 3. Install Windows

**Edition and licensing:**

| Edition | Support ends | How it's licensed |
|---|---|---|
| Windows 11 IoT Enterprise LTSC 2024 | 2034 | OEM-only, sold through distributors to device makers for fixed-purpose hardware. Not available to individuals for a general-purpose PC |
| Windows 11 Enterprise LTSC 2024 | 2029 | Volume Licensing only |

The 90-day evaluation ISOs can't be activated or converted to a permanent
license.

Activation is out of scope for this runbook. Everything after this section
works the same activated or not.

Both are 24H2-based. Secure Boot is currently disabled (firmware in setup
mode), which Windows 11 tolerates — it only requires a Secure Boot *capable*
system.

Everything below runs from Arch, so it works even if the old Windows no longer
boots.

### 3.1 Get the ISO

Wherever it comes from (Volume Licensing Service Center, Microsoft 365 admin
center, or the Evaluation Center), check it against the SHA-256 Microsoft
publishes for that exact ISO:

```sh
sha256sum ~/Downloads/<ltsc>.iso
```

### 3.2 Download drivers

The board is an ASRock X870 Riptide WiFi. Setup may not have drivers for its
network chips, so get these from ASRock's support page for the board (plus
NVIDIA's site) before you start:

| Driver | Hardware |
|---|---|
| LAN | Killer E3000 2.5GbE (Realtek-based) |
| WLAN + Bluetooth | MediaTek MT7925 Wi-Fi 7 |
| AMD chipset | X870 / Granite Ridge, including the Radeon iGPU |
| NVIDIA | GeForce RTX 5070 Ti (Blackwell — needs a current driver) |

They go onto the install USB in the next step and get installed after the first
login.

### 3.3 Write the install USB (Ventoy)

One [Ventoy](https://www.ventoy.net) stick carries both the Windows installer
and the Arch ISO needed for [section 4](#4-restoring-arch-boot). Ventoy
installs a small boot partition plus an exFAT data partition; ISOs are copied
onto the data partition as plain files and picked from a menu at boot. exFAT
has no 4 GiB file limit, so the Windows image needs no splitting. Any 16 GB+
USB 3 stick fits the ISOs and drivers; 64 GB leaves room for extra tools.

Get the Arch ISO from <https://archlinux.org/download/> and check it against
the published SHA-256 too.

**New stick? Check its real capacity first.** Fake-capacity sticks report a
size they don't have and silently corrupt data past the real limit — which
shows up as a Windows install failing halfway. This test is destructive, so
run it before Ventoy:

```sh
paru -S f3
sudo f3probe --destructive --time-ops /dev/sdX
```

**Install Ventoy** — this takes the **whole device** (`/dev/sdX`, not
`/dev/sdX1`) and erases everything on it:

```sh
paru -S ventoy-bin

lsblk -o NAME,SIZE,MODEL,TRAN          # find the stick: TRAN=usb
USB=/dev/sdX                           # ← set this
udisksctl unmount -b "${USB}1"         # if the desktop auto-mounted it

sudo ventoy -i -g "$USB"               # -g = GPT; asks for confirmation twice
```

**Copy the ISOs and drivers** onto the `Ventoy` partition:

```sh
udisksctl mount -b "${USB}1"           # mounts at /run/media/$USER/Ventoy
V=/run/media/$USER/Ventoy

cp ~/Downloads/<ltsc>.iso ~/Downloads/archlinux-*.iso "$V"/
mkdir "$V"/Drivers
cp -r ~/Downloads/<drivers>/* "$V"/Drivers/

sync
udisksctl unmount -b "${USB}1"
```

Ventoy ignores anything that isn't a bootable image, so `Drivers/` sits
alongside the ISOs without showing up in the boot menu. Windows reads exFAT
natively, so the drivers are reachable after the first login.

**Test-boot it once** (both entries) before the day you need it — some boards
are picky about specific sticks, and it's better to find out early.

Updating later: copy a newer ISO on and delete the old one — no re-flashing.
`sudo ventoy -u "$USB"` updates Ventoy itself without touching the ISOs.

### 3.4 Boot the installer

Plug in the stick, reboot, and press **F11** at the ASRock logo for the
one-time boot menu. Pick the **`UEFI:`** entry for the stick, not the plain
one — a legacy (CSM) boot makes setup refuse GPT disks.

Ventoy's menu lists every ISO on the stick. Pick the Windows one and, if asked,
**Boot in normal mode**. Secure Boot is off, so Ventoy's key-enrollment step
never appears.

### 3.5 Setup screens

1. Language, keyboard → **Install Windows 11**. If setup shows an "everything
   will be deleted" checkbox, it refers to the partition you pick next, not the
   whole machine
2. Product key → enter one, or **I don't have a product key**
3. Pick the edition if the ISO has several → accept the license
4. **Select location to install Windows 11** — the screen that matters

Disk numbers depend on enumeration order, so identify disks by their
partitions, not by "Disk 0/1". Windows shows binary units:

| Setup shows | Size | What it is | Action |
|---|---|---|---|
| Partition 1 (System) | 512 MB | ESP — systemd-boot and the Arch kernel | **Leave** |
| Partition 2 (MSR) | 16 MB | Microsoft reserved | **Leave** |
| Partition 3: Corona | 249.3 GB | Old C: | **Format**, then select it → **Next** |
| Partition 4 (Recovery) | 735 MB | WinRE | **Leave** |
| Partition 5: Nebula | 1657.2 GB | Data | **Leave** |
| Other disk, single partition | 1863.0 GB | Arch LVM (nvme0n1) | **Leave** |

The Windows disk totals 1907.7 GB, the Arch disk 1863.0 GB. **Never click
Delete on this screen**, and don't run "Extend" or "New" either.

Setup does not reformat an existing ESP when installing into an existing
partition. It writes `EFI/Microsoft/`, may overwrite the fallback
`EFI/BOOT/BOOTX64.EFI`, and puts Windows Boot Manager first in the UEFI boot
order. systemd-boot's files and the Arch kernel are left alone. Setup either
reuses p4 for WinRE or puts it in `C:\Recovery`; both are fine.

Setup reboots a few times. Because Windows Boot Manager is now first in the
boot order, it continues on its own. Leave the stick in (the drivers are on
it), but don't pick it from the boot menu again.

### 3.6 First-run setup (OOBE)

1. Region, keyboard
2. **Network** — if the LAN and Wi-Fi chips aren't recognized, choose **I don't
   have internet** and install the drivers after login
3. **Account** — Enterprise editions offer **Sign-in options → Domain join
   instead**, which creates a local account. No Microsoft account needed
4. **Privacy** — turn every toggle off. Diagnostic data can be fully disabled
   later with Group Policy (*Allow diagnostic data* = *Diagnostic data off*),
   which only Enterprise editions honour

### 3.7 First login

1. Run the installers from `Drivers\` on the stick: **chipset first**, then
   LAN and WLAN, then NVIDIA. Reboot when they ask
2. Settings → Windows Update → install everything, reboot, repeat until it's
   clean
3. Check Disk Management: Nebula has the drive letter you noted in
   [section 2](#2-before-you-start-from-arch), and nothing else changed

Then restore the Arch boot order ([section 4](#4-restoring-arch-boot)) before
going further — it's one reboot into the firmware menu.

---

## 4. Restoring Arch boot

**Usual case — only the boot order changed.** Pick "Linux Boot Manager" from
the firmware boot menu (F11 on this ASRock board) or move it to the top in
firmware setup. Once in Arch, `sudo bootctl install` makes it first again
permanently. systemd-boot auto-detects Windows Boot Manager on the same ESP, so
no loader entry is needed for Windows.

**If the ESP was wiped anyway**, boot the Ventoy stick (F11 → `UEFI:` entry)
and pick the Arch ISO:

```sh
vgchange -ay ArchVG
mount /dev/mapper/ArchVG-root /mnt
mount /dev/mapper/ArchVG-home /mnt/home
mount /dev/nvme1n1p1 /mnt/boot
arch-chroot /mnt

bootctl install                        # systemd-boot + NVRAM entry, first in boot order
pacman -S linux-zen amd-ucode          # rewrites kernel + microcode to /boot, rebuilds initramfs
tar -C /boot -xzf /home/<you>/boot-backup.tgz loader/   # restore loader entries
```

If the backup is gone, recreate `/boot/loader/entries/arch.conf`:

```
title   Arch Linux (zen)
linux   /vmlinuz-linux-zen
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen.img
options root=/dev/mapper/ArchVG-root rw quiet zswap.enabled=0
```

**If the ESP was reformatted**, also update the `/boot` line in `/etc/fstab`
with the new UUID from `blkid /dev/nvme1n1p1`.

---

## 5. Windows settings for dual boot

**Hardware clock in UTC.** Arch keeps the RTC in UTC (`RTC in local TZ: no`);
Windows assumes local time, so the clock jumps every time you switch OS. From
an elevated prompt:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

**Turn off Fast Startup.** It hibernates the kernel on shutdown, leaving NTFS
volumes dirty; Linux then mounts Nebula read-only or refuses it.

```powershell
powercfg /h off   # also removes hiberfil.sys
```

**Automatic device encryption.** 24H2 can turn on BitLocker device encryption
during OOBE. Check `manage-bde -status`; turn it off unless you want it, and if
you keep it, save the recovery key off the machine — changing the boot order
can trigger a recovery prompt.

**Developer Mode** (Settings → System → For developers). `setup_symlinks.ps1`
uses `New-Item -ItemType SymbolicLink`, which needs either Developer Mode or an
elevated shell.

---

## 6. Packages (scoop)

LTSC has no Microsoft Store, and `winget` (App Installer) is not guaranteed to
be present. Everything here comes from scoop:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
irm get.scoop.sh | iex

scoop install git                     # first — buckets are git repos; bundles Git Credential Manager
scoop bucket add extras
scoop bucket add nerd-fonts

# Shell
scoop install pwsh oh-my-posh fzf fd ripgrep bat zoxide duf delta
# Terminal + font (Windows Terminal may not ship inbox on LTSC)
scoop install extras/windows-terminal nerd-fonts/FantasqueSansMono-NF-Mono
# Editors + tools
scoop install neovim gitui yazi
# Desktop
scoop install extras/glazewm extras/zebar extras/flow-launcher
# Music
scoop install mpv yt-dlp python
# Downloads
scoop install aria2
```

What needs what:

| Package | Required by |
|---|---|
| `pwsh` | `wt/settings.json` defaults to the PowerShell 7 profile; `install_modules.ps1` writes the pwsh profile path |
| `oh-my-posh`, `zoxide`, `fzf`, `fd`, `bat`, `duf` | `powershell/profile.ps1` — the profile errors on startup without them |
| `delta` | `core.pager` in `git/gitconfig.windows` |
| FantasqueSansM Nerd Font Mono | Windows Terminal font face; Terminal-Icons and oh-my-posh glyphs |
| `python` | `pip install` for the Flow Launcher Music plugin |
| `mpv`, `yt-dlp` | `music` function and the Flow Launcher plugin |

---

## 7. Clone and link

```powershell
git clone --recurse-submodules git@github.com:ShinThirty/MyConfigurations.git $HOME\MyConfigurations
cd $HOME\MyConfigurations
.\setup_symlinks.ps1
.\powershell\install_modules.ps1
```

> The clone uses SSH, so either do [SSH keys](#8-ssh-keys) first, or clone over
> HTTPS and switch the remote afterwards.

The repo **must** be at `$HOME\MyConfigurations` — the profile stub and
`profile.ps1`'s fallback both hardcode that path.

`setup_symlinks.ps1` reads `symlinks.windows` and skips any target that already
exists (⚠️ in its output). Like the Unix version it never overwrites, so delete
stale real files and re-run.

`install_modules.ps1` writes the profile stub to
`$HOME\OneDrive\Documents\PowerShell\` and installs CompletionPredictor,
posh-git, Terminal-Icons and PSFzf from PSGallery.

---

## 8. SSH keys

Same six files as the other platforms, into `$HOME\.ssh\` (USB, not email or
chat):

| File | What it's for |
|---|---|
| `github` | GitHub auth |
| `sourcehut` | git.sr.ht auth |
| `signing_key` | Git commit signing |
| `signing_key.pub` | `user.signingkey` in `git/gitconfig.windows` |
| `config` | Host→key mapping |
| `allowed_signers` | `gpg.ssh.allowedSignersFile` |

Windows OpenSSH also refuses keys other users can read. Strip inherited ACLs:

```powershell
icacls $HOME\.ssh\github, $HOME\.ssh\sourcehut, $HOME\.ssh\signing_key /inheritance:r /grant:r "${env:USERNAME}:F"
```

Verify:

```powershell
ssh -T git@github.com
ssh -T git@git.sr.ht
git -C $HOME\MyConfigurations log --show-signature -1
```

---

## 9. Desktop

Full details in `glazewm/README.md`. The post-install steps that aren't automated:

- GlazeWM tray icon → **Run on system startup**
- Flow Launcher hotkey → `ctrl+space` (the default `alt+space` collides with GlazeWM)
- `Win+V` once to enable clipboard history
- Flow Launcher Music plugin dependencies (the plugin dir is symlinked in by
  `setup_symlinks.ps1`, but `lib/` is not tracked):

  ```powershell
  cd "$HOME\scoop\persist\flow-launcher\UserData\Plugins\Music"
  pip install -r requirements.txt -t lib
  ```

- Copy `~\Music\playlists\` back — the `music` function and the plugin both read it

---

## 10. aria2

```powershell
cd $HOME\MyConfigurations\aria2\windows   # install.ps1 uses relative paths
.\install.ps1
.\add_firewall_rules.ps1                   # elevated — opens 6881-6999 TCP/UDP
```

`install.ps1` copies the config and both `.vbs` launchers into
`~\.config\aria2\`, and creates an empty `aria2.session` only if none exists —
so restore the old session file (saved in [section 2](#2-before-you-start-from-arch))
first to resume unfinished downloads.

It also registers two Task Scheduler tasks: **Aria2** (at logon, no time
limit) and **Aria2 Update Trackers** (weekly). Check they exist with
`Get-ScheduledTask Aria2*`; if registration failed with "Access is denied",
re-run `install.ps1` elevated. Log out and back in (or
`Start-ScheduledTask Aria2`) to start aria2.

Check that `${HOME}` in `aria2.conf` resolved to your profile — aria2 expands
it itself, but Windows doesn't set `HOME` by default. With aria2 running:

```powershell
$body = '{"jsonrpc":"2.0","id":1,"method":"aria2.getGlobalOption"}'
(Invoke-RestMethod http://localhost:6800/jsonrpc -Method Post -Body $body).result.dir
# expect C:\Users\<you>/Downloads, not a literal ${HOME}
```

`aria2/README.md` says `winget install aria2`; on LTSC use the scoop package
from [section 6](#6-packages-scoop) instead.

---

## 11. Known gotchas

**The profile stub path assumes OneDrive folder backup.** `install_modules.ps1`
writes to `$HOME\OneDrive\Documents\PowerShell`. That is `$PROFILE` only when
OneDrive is backing up Documents (Known Folder Move). On a fresh local-account
LTSC install it usually isn't, and `$PROFILE` is
`$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` — the stub lands
in the wrong place and pwsh starts with no config. Check `$PROFILE` and either
sign in to OneDrive first or create the stub there by hand:

```powershell
New-Item -Force $PROFILE -Value '. "$HOME\MyConfigurations\powershell\profile.ps1"'
```

**Nebula's drive letter can change.** The fresh install assigns letters in
discovery order. Fix it in Disk Management before reinstalling apps that store
paths into it.

**`profile.ps1` has no guards.** Every tool it calls must be on PATH or pwsh
prints errors on every launch. If it does, the missing package is in the
[section 6](#6-packages-scoop) table.

**The scoop Windows Terminal may read settings from elsewhere.**
`symlinks.windows` links
`$LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`,
which is the Store/msix package's location. The scoop build is unpackaged and
may run in portable mode, reading settings from its own directory instead. If
WT comes up unthemed, check where it actually reads from (Settings → Open JSON
file) and link that path.

---

## 12. Verification

```powershell
# in a new Windows Terminal tab — should open pwsh with the gruvbox prompt
Get-Item $HOME\.gitconfig, $LOCALAPPDATA\nvim, $HOME\.glzr\glazewm\config.yaml | Select-Object FullName, LinkType, Target
which fzf fd rg bat zoxide yazi delta gitui nvim mpv
```

Then:

- `nvim` — lazy.nvim installs plugins on first launch; `:checkhealth` after
- `gitui` in a repo — gruvbox theme, vim keys
- `y` — yazi opens and the shell follows its cwd on quit
- `keys` — opens `powershell/cheatsheet.md`
- `music` — playlist picker comes up
- `alt+enter` — GlazeWM opens a terminal; Zebar bar visible
- `m` in Flow Launcher — Music plugin lists playlists
- `git commit` on a scratch change, then `git log --show-signature`
- Reboot into Arch: Nebula mounts read-write, clock is correct
