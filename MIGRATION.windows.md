# Migrating to a new Windows install

Runbook for (re)installing Windows 11 LTSC on the Arch/Windows dual-boot box and
standing this setup back up on it. Unlike macOS and Arch there is no bootstrap
script — the Windows side is a handful of scoop installs plus
`setup_symlinks.ps1` and `powershell/install_modules.ps1`, listed here in order.

Rough order: **back up → ISOs → install USB → install Windows → fix
the boot order → Windows settings → scoop → repo → SSH keys → desktop → network
share → personal apps → verify.**

> Scope note: the Windows side of this repo covers PowerShell, git, gitui, nvim,
> yazi, Windows Terminal, GlazeWM, Flow Launcher, aria2 and IdeaVim. Personal
> apps and data aren't managed by the repo; [section 12](#12-personal-apps-and-data)
> lists them so nothing gets lost.

---

## 1. The dual-boot layout

```
nvme1n1 (Windows disk)
├─p1  512M  EFI System    ← mounted at /boot on Arch: systemd-boot, vmlinuz-linux-zen,
│                            initramfs-linux-zen.img, amd-ucode.img all live HERE
├─p2   16M  MSR
├─p3  249G  NTFS "Corona" ← C:  — the ONLY partition that gets formatted
├─p4  735M  WinRE
└─p5  1.6T  NTFS "Nebula" ← D:  — data, survives the reinstall
nvme0n1  → Arch LVM (ArchVG-root, ArchVG-home) — Windows setup never touches it
```

Drive letters the setup depends on: **C:** Corona, **D:** Nebula, **E:** the
external USB SSD (osu! data), **Z:** the router's network share (password
database, [section 10](#10-network-share-and-password-database)).

**The ESP is shared.** Arch's kernel lives on the Windows disk, so deleting p1
in Windows setup leaves Arch unbootable even though its root is on the other
drive. The plan is to reuse the existing partition scheme: format and install
into p3 only.

---

## 2. Before you start

### 2.1 From Arch

```sh
sudo tar -C /boot -czf ~/boot-backup.tgz .   # ~70 MB, lands on nvme0n1, safe
blkid /dev/nvme1n1p1                         # note the UUID — currently 132D-60E4
```

`/etc/fstab` mounts `/boot` by that UUID. If the ESP is ever reformatted the
UUID changes and Arch drops to an emergency shell (see [section 4](#4-restoring-arch-boot)).

### 2.2 From the old Windows

Only C: is formatted. Nebula (D:), the Arch disk and the external SSD are never
touched, so D: is where the backup goes. Everything on C: that isn't copied off
is gone.

1. Save the **BitLocker recovery key** for any encrypted volume
   (`manage-bde -status`), or decrypt Nebula first
2. Check the OneDrive tray icon says **Up to date**. Desktop, Documents and
   Pictures are redirected into OneDrive, so the cloud copy is the only one that
   survives — and they're deliberately *not* in the backup below
3. Edge is signed in with sync on, so bookmarks, passwords and extensions come
   back on sign-in. Nothing to copy
4. Run the backup, from any PowerShell on the old install:

```powershell
$B = 'D:\Migration'
$items = @(
    # keys and secrets (sections 8, 12)
    '.ssh', '.config\age', '.aws', '.trading', '.tradingrc'
    # Claude Code (section 12)
    '.claude', '.claude.json'
    # local folders that are NOT in OneDrive ('Documents' here is the local leftover,
    # not the redirected one)
    'Documents', 'Downloads', 'Music', 'Utilities'
    # app state (sections 9-12)
    '.config\aria2\aria2.session'
    'scoop\persist\flow-launcher\UserData\Settings'
    'scoop\persist\keepassxc\config'
    'scoop\persist\sharex'
    'AppData\Roaming\osu\storage.ini', 'AppData\Roaming\osu\framework.ini'
    'AppData\Roaming\OpenRGB\OpenRGB.json'
    # optional history
    'AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
    'AppData\Local\zoxide\db.zo'
)
# robocopy prints only errors. /R:1 /W:1 skips a locked file instead of retrying it for
# days; /XJ skips junctions like Documents\My Music, which point back at other folders
foreach ($i in $items) {
    $src = Join-Path $HOME $i; $dst = Join-Path "$B\home" $i
    if (Test-Path $src -PathType Container) { robocopy $src $dst /E /XJ /R:1 /W:1 /NP /NFL /NDL /NJH /NJS }
    elseif (Test-Path $src) { New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null; Copy-Item -Force $src $dst }
    else { Write-Host "missing: $i" -ForegroundColor Yellow }
}
# Vortex profiles, load order and settings, minus its caches. Quit Vortex first —
# its databases are locked while it runs
robocopy "$env:APPDATA\Vortex" "$B\home\AppData\Roaming\Vortex" /E /XD Cache "Code Cache" GPUCache DawnCache temp /XJ /R:1 /W:1 /NP /NFL /NDL /NJH /NJS
# Steam's local per-game configs (the games themselves are on D:\SteamLibrary)
robocopy "${env:ProgramFiles(x86)}\Steam\userdata" "$B\steam-userdata" /E /XJ /R:1 /W:1 /NP /NFL /NDL /NJH /NJS
# Manually installed fonts (Noto Sans/Serif SC)
New-Item -ItemType Directory -Force "$B\fonts" | Out-Null
Copy-Item "$env:windir\Fonts\NotoS*SC*" "$B\fonts"
# The network drivers in use, as a fallback if the new install can't get online (section 3.2).
# Windows keeps each oemNN.inf as a byte-identical copy of the INF in its driver store package
Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceClass -eq 'NET' -and $_.HardWareID -like 'PCI\*' -and $_.InfName -like 'oem*' } | ForEach-Object {
    $h = (Get-FileHash "$env:windir\INF\$($_.InfName)").Hash
    Get-ChildItem "$env:windir\System32\DriverStore\FileRepository\*\*.inf" | Where-Object { (Get-FileHash $_).Hash -eq $h } |
        ForEach-Object { robocopy $_.DirectoryName "$B\drivers\$($_.Directory.Name)" /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS }
}
# Inventories. The scoopfile leaves out apps you don't want back; add names to drop more
$export = scoop export | Out-String | ConvertFrom-Json
$export.apps = @($export.apps | Where-Object Name -notin 'ghostscript', 'zoom', 'sharpkeys')
$export | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 "$B\scoopfile.json"
net use > "$B\net-use.txt"
```

`D:\Migration\home` mirrors `$HOME`; the section that uses each piece says
where it goes back. Run the block again right before rebooting into the
installer — robocopy only copies what changed since, so it takes seconds.
`.claude` includes the Claude Code login token, so delete `D:\Migration` once
everything is restored.

Not worth copying: the Steam games, Vortex's mods and downloads, and Mental
Omega are already on D:; osu!'s data is on the external SSD; Discord, Webull
and Wabbajack are cloud accounts — just log in again. `C:\Users\LINGNA~1`
is an orphaned installer temp folder.

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
works the same activated or not, with one exception: an unactivated install
greys out Settings → Personalization, so [section 5.2](#52-keyboard-mouse-language-and-theme)
sets dark mode through the registry instead.

Both are 24H2-based. Secure Boot is currently disabled (firmware in setup
mode), which Windows 11 tolerates — it only requires a Secure Boot *capable*
system.

Sections 3.1–3.3 work from either OS. The old Windows is the easier place while
it still boots — Ventoy is already in its scoop list. The Arch commands are the
fallback if it doesn't. ([Section 2.1](#21-from-arch)'s `/boot` backup still
has to happen from Arch.)

### 3.1 Get the ISO

Wherever it comes from (Volume Licensing Service Center, Microsoft 365 admin
center, or the Evaluation Center), check it against the SHA-256 Microsoft
publishes for that exact ISO:

```powershell
Get-FileHash "$HOME\Downloads\<ltsc>.iso"    # Windows; SHA-256 is the default
```

```sh
sha256sum ~/Downloads/<ltsc>.iso             # Arch
```

Microsoft doesn't always publish a hash you can reach. The Evaluation Center's
hash sheet still lists the May 2024 image, not the September 2024 refresh
(26100.1742) its download link now serves, and the subscriber portals show
hashes only after signing in. Without an official hash, check the file against
at least two independent catalogues — never only the page you downloaded from,
which would only prove the download wasn't corrupted.

### 3.2 Drivers

Nothing to download in advance, as long as the Ethernet cable is plugged in.
The board is an ASRock X870 Riptide WiFi:

| Hardware | Driver after installation |
|---|---|
| LAN: Killer E3100G 2.5GbE (Realtek RTL8125, PCI `10EC:3000`) | Built in — Windows' own `rt640x64.inf` matches it, including the April 2024 copy the 26100 image ships. Ethernet works at first login |
| Wi-Fi 7 + Bluetooth: AMD RZ717 (MediaTek, PCI `14C3:0717`, USB `0E8D:0717`) | No built-in driver. ASRock's support page lists packages for two Wi-Fi modules — take the **MediaTek** WLAN and Bluetooth ones. The AzureWave EB601NF packages are Realtek drivers for the other module and don't match |
| AMD chipset | X870 / Granite Ridge: PSP, GPIO, I2C, SMBus and four unnamed ACPI devices. AMD's chipset package (amd.com → Chipsets → AM5 → X870). Its *3D V-Cache Performance Optimizer* only matters on two-CCD X3D chips, not the 9800X3D |
| NVIDIA GeForce RTX 5070 Ti | Blackwell, so it needs a current driver — nvidia.com, or NVCleanstall to leave out the NVIDIA App and telemetry |
| Fingerprint reader: U.are.U 4500 (USB `05BA:000A`) | Crossmatch "U.are.U Fingerprint Reader Driver (WBF)" 5.0.0.5. Its readme stops at Windows 10, but it installs and starts on LTSC 2024. Needed for Windows Hello fingerprint |

If Ethernet doesn't come up anyway, the backup in [section 2.2](#22-from-the-old-windows)
copied the old install's LAN and Wi-Fi driver packages to `D:\Migration\drivers`
([section 3.7](#37-first-login)).

### 3.3 Write the install USB (Ventoy)

One [Ventoy](https://www.ventoy.net) stick carries both the Windows installer
and the Arch ISO needed for [section 4](#4-restoring-arch-boot). Ventoy
installs a small boot partition plus an exFAT data partition; ISOs are copied
onto the data partition as plain files and picked from a menu at boot. exFAT
has no 4 GiB file limit, so the Windows image needs no splitting. Any 16 GB+
USB 3 stick fits both ISOs; 64 GB leaves room for extra tools.

Get the Arch ISO from <https://archlinux.org/download/> and check it against
the published SHA-256 too.

**New stick? Check its real capacity first.** Fake-capacity sticks report a
size they don't have and silently corrupt data past the real limit — which
shows up as a Windows install failing halfway. Test before installing Ventoy:

- **Windows:** H2testw (portable, from heise.de). It fills the free space with
  test files and reads them back, so run it on the empty stick
- **Arch:** `f3probe` is destructive:

  ```sh
  paru -S f3
  sudo f3probe --destructive --time-ops /dev/sdX
  ```

**Install Ventoy** — this takes the **whole stick** and erases everything on it.

From Windows (Ventoy2Disk asks for elevation):

1. Run `~\scoop\apps\ventoy\current\Ventoy2Disk.exe` — scoop adds no shortcut
   for it
2. **Option → Partition Style → GPT**
3. **Device:** pick the stick. Ventoy2Disk lists only USB drives unless
   *Option → Show All Devices* is ticked — leave it unticked, so the NVMe disks
   can't be chosen
4. **Install**, and confirm both prompts

From Arch — the **whole device** (`/dev/sdX`, not `/dev/sdX1`):

```sh
paru -S ventoy-bin

lsblk -o NAME,SIZE,MODEL,TRAN          # find the stick: TRAN=usb
USB=/dev/sdX                           # ← set this
udisksctl unmount -b "${USB}1"         # if the desktop auto-mounted it

sudo ventoy -i -g "$USB"               # -g = GPT; asks for confirmation twice
```

**Copy the ISOs** onto the `Ventoy` partition. On Windows it shows up as a
drive labelled `Ventoy`; eject it from the tray when done:

```powershell
$V = "$((Get-Volume -FileSystemLabel Ventoy).DriveLetter):"
Copy-Item "$HOME\Downloads\<ltsc>.iso", "$HOME\Downloads\archlinux-*.iso" "$V\"
```

On Arch:

```sh
udisksctl mount -b "${USB}1"           # mounts at /run/media/$USER/Ventoy
V=/run/media/$USER/Ventoy

cp ~/Downloads/<ltsc>.iso ~/Downloads/archlinux-*.iso "$V"/

sync
udisksctl unmount -b "${USB}1"
```

**Test-boot it once** (both entries) before the day you need it — some boards
are picky about specific sticks, and it's better to find out early.

Updating later: copy a newer ISO on and delete the old one — no re-flashing.
To update Ventoy itself without touching the ISOs, use **Update** in
Ventoy2Disk, or `sudo ventoy -u "$USB"` on Arch.

### 3.4 Boot the installer

**Unplug the external SSD first**, so setup can't list it and it doesn't grab a
drive letter before you're ready (plug it back in at [section 3.7](#37-first-login)).

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
| Partition 5: Nebula | 1657.2 GB | Data (D:) — your backup is on it | **Leave** |
| Other disk, single partition | 1863.0 GB | Arch LVM (nvme0n1) | **Leave** |

The Windows disk totals 1907.7 GB, the Arch disk 1863.0 GB. **Never click
Delete on this screen**, and don't run "Extend" or "New" either.

Setup does not reformat an existing ESP when installing into an existing
partition. It writes `EFI/Microsoft/`, may overwrite the fallback
`EFI/BOOT/BOOTX64.EFI`, and puts Windows Boot Manager first in the UEFI boot
order. systemd-boot's files and the Arch kernel are left alone. Setup either
reuses p4 for WinRE or puts it in `C:\Recovery`; both are fine.

Setup reboots a few times. Because Windows Boot Manager is now first in the
boot order, it continues on its own; don't pick the stick from the boot menu
again.

### 3.6 First-run setup (OOBE)

1. Region, keyboard
2. **Network** — Ethernet should already be connected. If it isn't, choose
   **I don't have internet** and install the LAN driver after login
   ([section 3.7](#37-first-login))
3. **Account** — Enterprise editions offer **Sign-in options → Domain join
   instead**, which creates a local account. Despite the name, it joins no
   domain. No Microsoft account needed. Name it **ShinThirty** again: Claude Code
   keys its per-project memory by path (`~\.claude\projects\C--Users-ShinThirty-…`),
   and the backup assumes the same profile path. Signing in with a Microsoft
   account here would name the profile folder after the first five characters
   of its email instead; to use one, link it later from Settings → Accounts →
   Your info, which keeps the folder name
4. **Privacy** — turn every toggle off. [Section 5.3](#53-telemetry) later
   locks them off with policies and turns diagnostic data fully off, which only
   Enterprise editions allow

### 3.7 First login

1. Remove the Ventoy stick, then plug the external SSD back in
2. Check Disk Management: Nebula is **D:**, the external SSD is **E:**, and
   nothing else changed. Fix letters here before installing anything that
   stores paths into them
3. **No network?** Device Manager → the Ethernet controller → Update driver →
   *Browse my computer* → `D:\Migration\drivers` (tick *Include subfolders*).
   Same for the Wi-Fi adapter if you need it
4. Drivers from [section 3.2](#32-drivers), **chipset first**, rebooting after
   each: AMD chipset, then the MediaTek Wi-Fi and Bluetooth packages, then the
   fingerprint driver. Windows Update's **Advanced options → Optional updates →
   Driver updates** is the alternative, with whatever versions Microsoft has.
   If an ASRock LAN package offers **Killer Intelligence Center**, skip it:
   it's an optional Store app, and the driver works without it
5. NVIDIA driver from nvidia.com — choose **NVIDIA Graphics Driver**, not
   *…and NVIDIA App* — or a driver-only package built with NVCleanstall.
   **NVIDIA Control Panel** won't appear either way: it's a Store app the
   installer fetches from the Microsoft Store, which LTSC doesn't have.
   Resolution, refresh rate and HDR are in Windows' display settings; G-SYNC,
   colour range and DSR need the Control Panel

Updating the BIOS (optional): ASRock's Instant Flash reads FAT32 only, so use
a spare stick — the Ventoy partition is exFAT, and keep that stick intact for
recovery. Flashing resets every setting (EXPO, SVM, fan curves), so note them
first. After going from 3.50 to 4.43, systemd-boot's menu still came up; if
it doesn't, see [section 4](#4-restoring-arch-boot)

Then check that Arch still boots ([section 4](#4-restoring-arch-boot)) before
going further — usually nothing needs fixing.

---

## 4. Restoring Arch boot

Reboot and see what the machine boots into, then check from Arch.
`bootctl status` needs no root:

```sh
bootctl status | sed -n '/Boot Loaders Listed/,$p'
lsblk -no UUID /dev/nvme1n1p1          # still 132D-60E4?
```

**Nothing changed — the common case.** On the 2026-10 LTSC reinstall, setup
left the boot order alone: Linux Boot Manager stayed first and Windows Boot
Manager was added but marked *inactive*. That's fine — systemd-boot
auto-detects Windows Boot Manager on the same ESP and chainloads it from its
own menu, so neither a firmware entry nor a loader entry is needed. Confirm
the menu shows **Windows Boot Manager** and that it starts the new install.

**Windows took over the boot order.** The machine boots straight into Windows.
Pick "Linux Boot Manager" from the firmware boot menu (F11 on this ASRock
board) or move it to the top in firmware setup, then once in Arch run
`sudo bootctl install` to make it first again permanently. Windows Update can
do this later too, when it updates its own boot files — same fix.

What the entries are:

| Firmware entry | File | What it is |
|---|---|---|
| Linux Boot Manager | `EFI/systemd/systemd-bootx64.efi` | Current systemd-boot |
| Fallback Linux Boot Manager | `EFI/systemd/systemd-boot-fallbackx64.efi` | The previous systemd-boot version, kept when systemd updates. Tried next if the current one fails to start |
| Windows Boot Manager | `EFI/Microsoft/Boot/bootmgfw.efi` | Written by Windows setup; started from systemd-boot's menu |
| *(none)* | `EFI/BOOT/BOOTX64.EFI` | Removable-media default path, used when NVRAM has no entries (e.g. after a BIOS reset). `bootctl` keeps a copy of systemd-boot here; Windows setup may overwrite it |

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
tar -C /boot -xzf /home/<you>/boot-backup.tgz ./loader  # restore loader config + entries
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

## 5. Windows settings

Run these from an elevated Windows PowerShell — pwsh isn't installed until
[section 6](#6-packages-scoop).

### 5.1 Dual boot

**Hardware clock in UTC.** Arch keeps the RTC in UTC (`RTC in local TZ: no`);
Windows assumes local time, so the clock jumps every time you switch OS:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

**Turn off Fast Startup.** It hibernates the kernel on shutdown, leaving NTFS
volumes dirty; Linux then mounts Nebula read-only or refuses it.

```powershell
powercfg /h off   # also removes hiberfil.sys
```

This also removes Hibernate. The old install kept Hibernate and turned off
only Fast Startup (Control Panel → Power Options → *Choose what the power
buttons do*). If you want that instead, `powercfg /h on` and untick Fast
Startup there — but a hibernated Windows leaves Nebula just as dirty, so shut
down fully before booting Arch.

**Automatic device encryption.** 24H2 can turn on BitLocker device encryption
during OOBE. Check `manage-bde -status`; turn it off unless you want it, and if
you keep it, save the recovery key off the machine — changing the boot order
can trigger a recovery prompt.

**Developer Mode** (Settings → System → For developers). `setup_symlinks.ps1`
uses `New-Item -ItemType SymbolicLink`, which needs either Developer Mode or an
elevated shell. Only pwsh honours Developer Mode; Windows PowerShell 5.1 still
needs elevation (see [section 7](#7-clone-and-link)).

### 5.2 Keyboard, mouse, language and theme

**Caps Lock ⇄ Esc.** The old install swapped them with SharpKeys, which just
writes this value — no need to install it. Reboot to apply:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" /v "Scancode Map" /t REG_BINARY /d 00000000000000000300000001003A003A00010000000000 /f
```

**Dark mode**, for apps and the system. Works unactivated:

```powershell
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-ItemProperty $k -Name AppsUseLightTheme -Value 0
Set-ItemProperty $k -Name SystemUsesLightTheme -Value 0
```

**Mouse and keyboard.** Enhance pointer precision off, shortest key-repeat
delay, NumLock on at boot, and the Sticky Keys shortcut (Shift ×5) off. Sign
out to apply:

```powershell
$m = 'HKCU:\Control Panel\Mouse'
'MouseSpeed', 'MouseThreshold1', 'MouseThreshold2' | ForEach-Object { Set-ItemProperty $m -Name $_ -Value '0' }
Set-ItemProperty 'HKCU:\Control Panel\Keyboard' -Name KeyboardDelay -Value '0'
Set-ItemProperty 'HKCU:\Control Panel\Keyboard' -Name InitialKeyboardIndicators -Value '2'
Set-ItemProperty 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name Flags -Value '506'
```

**Chinese.** The old install ran non-Unicode programs in Chinese (system
locale zh-CN, code page 936) and had Microsoft Pinyin next to the US keyboard:

```powershell
Set-WinSystemLocale zh-CN   # reboot to apply
```

Then Settings → Time & language → Language & region → **Add a language** →
中文(中华人民共和国), leaving *Set as my Windows display language* unticked so
the UI stays English. That pulls Microsoft Pinyin from Windows Update, so do it
after the network drivers are in. `Win+Space` switches input methods.

### 5.3 Telemetry

Diagnostic data fully **off** is an Enterprise and Education setting — Home and
Pro can't go below *Required*. The OOBE privacy toggles ([section 3.6](#36-first-run-setup-oobe))
are ordinary settings that can be switched back on; these are the policy values
Group Policy would write, which keep them off and grey them out in Settings.
Reboot to apply — one reboot after 5.2 and 5.3 covers both:

```powershell
function Set-Policy($key, $name, $value) { reg add $key /v $name /t REG_DWORD /d $value /f | Out-Null }
$w = 'HKLM\SOFTWARE\Policies\Microsoft\Windows'

# Diagnostic data off, no feedback prompts, no crash reports
Set-Policy "$w\DataCollection" AllowTelemetry 0
Set-Policy "$w\DataCollection" DoNotShowFeedbackNotifications 1
Set-Policy "$w\Windows Error Reporting" Disabled 1
# Advertising ID, activity history, suggested apps
Set-Policy "$w\AdvertisingInfo" DisabledByGroupPolicy 1
Set-Policy "$w\System" PublishUserActivities 0
Set-Policy "$w\System" UploadUserActivities 0
Set-Policy "$w\CloudContent" DisableWindowsConsumerFeatures 1
# Per user: no ads or tips "tailored" from diagnostic data, and Start menu search stays
# local instead of sending each query to Bing (Explorer's search box loses its history too)
Set-Policy 'HKCU\Software\Policies\Microsoft\Windows\CloudContent' DisableTailoredExperiencesWithDiagnosticData 1
Set-Policy 'HKCU\Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions 1
# Edge's own diagnostic data. Edge then says it's "managed by your organization" — harmless
Set-Policy 'HKLM\SOFTWARE\Policies\Microsoft\Edge' DiagnosticData 0

# The service that uploads diagnostic data
Stop-Service DiagTrack
Set-Service DiagTrack -StartupType Disabled

# pwsh reports to Microsoft on every start unless this is set before it launches;
# the profile runs too late
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
```

What still talks to Microsoft, by design: Windows Update, Defender's cloud
protection and SmartScreen, and Edge and OneDrive sync. To stop Defender
uploading suspicious files, turn off **Automatic sample submission** (Windows
Security → Virus & threat protection → Manage settings) but leave cloud-delivered
protection on. Windows Security then shows a warning you can dismiss.

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
scoop install pwsh oh-my-posh fzf fd ripgrep bat zoxide duf delta less
# Terminal + font. LTSC ships without Windows Terminal; until this, consoles open in conhost
scoop install extras/vcredist2022 extras/windows-terminal nerd-fonts/FantasqueSansMono-NF-Mono
# Editors + tools
scoop install neovim extras/neovim-qt gitui yazi
# yazi previews
scoop install 7zip ffmpeg jq poppler resvg imagemagick
# nvim: parsers are compiled; mason installs npm, pypi and cargo packages
scoop install tree-sitter mingw nodejs rustup-gnu
# Desktop
scoop install extras/glazewm extras/zebar extras/flow-launcher extras/sharex
# Music
scoop install mpv yt-dlp python
# Downloads
scoop install aria2

# yazi detects file types with Git for Windows' file(1)
[Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', "$HOME\scoop\apps\git\current\usr\bin\file.exe", 'User')

# rustup-gnu installs rustup but no toolchain, and a plain `rustup default stable`
# picks MSVC, which can't link without Visual Studio. Pin the GNU host first
rustup set default-host x86_64-pc-windows-gnu
rustup default stable
```

**Shortcut:** `scoop import D:\Migration\scoopfile.json` (from
[section 2.2](#22-from-the-old-windows)) reinstalls the old install's app and
bucket list, personal apps included, minus what the backup filtered out
(ghostscript, zoom, sharpkeys). It installs each app's latest version, not the
one recorded in the file. It doesn't cover pwsh, oh-my-posh,
Windows Terminal or Rust, which came from winget and the Store there — so run
the block above too; scoop skips anything already installed.

What needs what:

| Package | Required by |
|---|---|
| `pwsh` | `wt/settings.json` defaults to the PowerShell 7 profile; `install_modules.ps1` refuses to run without it. Update it with `scoop update pwsh` from Windows PowerShell — scoop runs inside pwsh and can't replace it from there |
| `oh-my-posh`, `zoxide`, `fzf`, `fd`, `bat`, `duf` | `powershell/profile.ps1` — the profile errors on startup without them |
| `delta` | `core.pager` in `git/gitconfig.windows` |
| `less` | The pager delta and bat hand off to. scoop's git doesn't put Git for Windows' own `less` on PATH |
| `vcredist2022` | The VC++ runtime; scoop's Windows Terminal manifest suggests it, and a clean install may not have it. Its installer asks for elevation |
| FantasqueSansM Nerd Font Mono | Windows Terminal font face, `nvim/ginit.vim`; Terminal-Icons and oh-my-posh glyphs |
| `neovim-qt` | The GUI that reads `nvim/ginit.vim` |
| `7zip`, `ffmpeg`, `jq`, `poppler`, `resvg`, `imagemagick` | yazi previews: archives, video thumbnails, JSON, PDF, SVG, fonts/HEIC (yazi's Windows install docs) |
| `tree-sitter`, `mingw` | nvim's tree-sitter-manager builds parsers with the `tree-sitter` CLI and `cc` |
| `nodejs` | mason: 8 of the 18 nvim tools are npm packages (css/html/json/eslint LSPs, emmet-ls, vim-language-server, prettierd, markdownlint) |
| `rustup-gnu` | mason builds `shellharden` with cargo. The GNU toolchain needs no Visual Studio; the old install used rustup's MSVC toolchain plus VS 2022 and the Windows SDK |
| `python` | `pip install` for the Flow Launcher Music plugin; mason's `ty` (pypi) |
| `mpv`, `yt-dlp` | `music` function and the Flow Launcher plugin |
| `sharex` | Screenshots and screen recording in place of Snipping Tool, which LTSC only ships in its old form (`glazewm/README.md`) |

---

## 7. Clone and link

Run this whole section from **pwsh** — type `pwsh` at the Windows PowerShell
prompt. Windows PowerShell 5.1 trips over all three steps:

- it ignores Developer Mode, so `setup_symlinks.ps1` fails unless elevated
- `Install-Module` there installs into `WindowsPowerShell\Modules`, which pwsh
  never loads — `install_modules.ps1` refuses to run under 5.1 for that reason
- it reads BOM-less scripts in the ANSI code page (`setup_symlinks.ps1` is saved
  with a BOM so this one at least parses)

```powershell
# -c core.autocrlf=false: ~\.gitconfig (which sets it) isn't linked yet, and scoop
# git's system default (true) would check every file out with CRLF
git clone -c core.autocrlf=false --recurse-submodules git@github.com:ShinThirty/MyConfigurations.git $HOME\MyConfigurations
cd $HOME\MyConfigurations
.\setup_symlinks.ps1
.\powershell\install_modules.ps1
ya pkg install                        # yazi's gruvbox-dark flavor and mime-ext plugin, from yazi/package.toml
```

> The clone uses SSH, so either do [SSH keys](#8-ssh-keys) first, or clone over
> HTTPS and switch the remote afterwards.

The repo **must** be at `$HOME\MyConfigurations` — the profile stub and
`profile.ps1`'s fallback both hardcode that path.

`setup_symlinks.ps1` reads `symlinks.windows` and skips any target that already
exists (⚠️ in its output). Like the Unix version it never overwrites, so delete
stale real files and re-run. The likely one: Windows Terminal writes a default
`~\scoop\persist\windows-terminal\settings\settings.json` the first time it
runs.

`install_modules.ps1` writes the profile stub to `Documents\PowerShell\` —
wherever Documents currently is, which is `OneDrive\Documents` once OneDrive
folder backup is on, so set up OneDrive ([section 12.2](#122-data)) before this
section — and installs CompletionPredictor, posh-git,
Terminal-Icons and PSFzf from PSGallery.

---

## 8. SSH keys

Same six files as the other platforms, from `D:\Migration\home\.ssh\` into
`$HOME\.ssh\`:

| File | What it's for |
|---|---|
| `github` | GitHub auth |
| `sourcehut` | git.sr.ht auth |
| `signing_key` | Git commit signing |
| `signing_key.pub` | `user.signingkey` in `git/gitconfig.windows` |
| `config` | Host→key mapping |
| `allowed_signers` | `gpg.ssh.allowedSignersFile` |

`known_hosts` is optional — without it, SSH asks once per host.

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
- **Flow Launcher** — quit it, copy `D:\Migration\home\scoop\persist\flow-launcher\UserData\Settings\`
  over `~\scoop\persist\flow-launcher\UserData\Settings\`, start it again. That
  restores everything below; set them by hand if you skip the restore:
  - hotkey `ctrl+space` (the default `alt+space` collides with GlazeWM)
  - **Start Flow Launcher on system startup** — check it actually starts after
    a reboot, and toggle it off/on if not
  - **Search with Pinyin**
- **Zebar** — the old install ran the starter pack's **`with-glazewm`** widget
  (`~\.glzr\zebar\settings.json`: pack `glzr-io.starter`, widget
  `with-glazewm`, preset `default`). Pick it from the Zebar tray icon if a fresh
  install comes up with another one
- **ShareX** (screenshots, in place of Snipping Tool) — before its first launch,
  copy `D:\Migration\home\scoop\persist\sharex\` over `~\scoop\persist\sharex\`.
  That restores the old settings: captures are copied to the clipboard and saved
  to a file, never uploaded (a fresh install uploads to Imgur by default), plus
  the default hotkeys listed in `glazewm/README.md`. Then Application settings →
  Integration → **Run ShareX when Windows starts**
- `Win+V` once to enable clipboard history
- Flow Launcher Music plugin dependencies (the plugin dir is symlinked in by
  `setup_symlinks.ps1`, but `lib/` is not tracked):

  ```powershell
  cd "$HOME\scoop\persist\flow-launcher\UserData\Plugins\Music"
  pip install -r requirements.txt -t lib
  ```

- Copy `D:\Migration\home\Music\` back to `~\Music\` — the `music` function and
  the plugin both read `playlists\`

---

## 10. Network share and password database

The password database isn't on C: — KeePassXC opens it straight from the
router's USB share, mapped as **Z:**. Map it again with the share path and user
name recorded in `D:\Migration\net-use.txt`:

```powershell
cmdkey /add:<share-host> /user:<user> /pass      # prompts for the password
net use Z: \\<share-host>\<share> /persistent:yes
```

Then KeePassXC:

1. Copy `D:\Migration\home\scoop\persist\keepassxc\config\` into
   `~\scoop\persist\keepassxc\config\` before the first launch. That restores
   its settings and recent-databases list
2. The database needs only its password — there's no key file
3. Settings → Browser Integration → tick **Edge** again. The native-messaging
   registration lives in the registry, not the config dir, so the restore
   doesn't bring it back

---

## 11. aria2

```powershell
cd $HOME\MyConfigurations\aria2\windows   # install.ps1 uses relative paths
.\install.ps1
.\add_firewall_rules.ps1                   # elevated — opens 6881-6999 TCP/UDP
```

`install.ps1` copies the config and both `.vbs` launchers into
`~\.config\aria2\`, and creates an empty `aria2.session` only if none exists —
so copy `D:\Migration\home\.config\aria2\aria2.session` there first to resume
unfinished downloads.

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

## 12. Personal apps and data

None of this is managed by the repo. This repo is public, so the data table is
deliberately generic — `D:\Migration` and the old `scoopfile.json` are the real
checklist.

### 12.1 Apps

**From scoop** — `scoop import` ([section 6](#6-packages-scoop)) covers these,
including the `java` and `games` buckets. `ghostscript`, `zoom` and `sharpkeys`
are left out: the backup in [section 2.2](#22-from-the-old-windows) filters
them from the scoopfile. SharpKeys isn't needed because
[section 5.2](#52-keyboard-mouse-language-and-theme) writes the same registry
value directly.

| App | What to redo after install |
|---|---|
| `keepassxc` | [Section 10](#10-network-share-and-password-database) |
| `claude-code` | `claude` CLI; re-auth on first run. The old install also had a native copy in `~\.local\bin` that wasn't on PATH — skip it |
| `osulazer` (games) | Point it back at the SSD — see the data table |
| `temurin-jre` (java) | Sets `JAVA_HOME` |
| `age`, `aws`, `terraform`, `uv`, `deno`, `jid`, `fastfetch` | General CLI — none of it is referenced by this repo's configs. `age` matters: the encrypted files in the data table are useless without it |
| `ventoy` | Only for rebuilding the install stick |
| `sharpkeys` | Not needed — [section 5.2](#52-keyboard-mouse-language-and-theme) writes the same registry value directly |

**Outside scoop** — vendor installers, since there's no Store or winget:

| App | What to redo after install |
|---|---|
| Steam | Settings → Storage → add `D:\SteamLibrary`; the games there are picked up without re-downloading. Steam Cloud restores most configs; `D:\Migration\steam-userdata` is the fallback |
| Mental Omega | Installed in `D:\Games\Mental Omega`, so the game survives; only the Start menu shortcut is lost |
| Vortex | Copy `D:\Migration\home\AppData\Roaming\Vortex\` to `%APPDATA%\Vortex\` before the first launch (profiles, load order, settings). Its mods and downloads aren't on C:. Its mod installer needs the **.NET 9 Desktop Runtime** (x64) and pins 9 exactly, so scoop's `windowsdesktop-runtime` (.NET 10) doesn't cover it — get 9 from Microsoft's .NET download page if Vortex's installer doesn't add it |
| Discord, Webull Desktop, Wabbajack | Log in |
| Cloudflare One Client (WARP) | Sign in / re-enroll |
| NVIDIA App | Left out — the driver alone is enough ([section 3.7](#37-first-login)) |
| OpenRGB | Only if you still use it — config is `D:\Migration\home\AppData\Roaming\OpenRGB\OpenRGB.json` |
| Microsoft Edge | Included in LTSC. Sign in to sync; add the KeePassXC-Browser extension if sync doesn't bring it |

`~\Utilities` (restored with the rest of `home\`) holds the mouse's
configuration tool and HWMonitor — both portable.

**Fonts:** Noto Sans SC and Noto Serif SC — `D:\Migration\fonts`, right-click →
*Install for all users*. JetBrainsMono Nerd Font Mono was also installed
(`scoop install nerd-fonts/JetBrainsMono-NF-Mono`), though nothing in this repo
uses it.

### 12.2 Data

| What | Notes |
|---|---|
| Desktop, Documents, Pictures | In OneDrive, not in the backup. LTSC doesn't ship OneDrive, so install it from Microsoft's standalone installer (`https://go.microsoft.com/fwlink/?linkid=844652`, signed by Microsoft Corporation). Sign in, then turn on backup for all three when it offers, or later under OneDrive settings → Sync and backup → Manage back up ([section 13](#13-known-gotchas)). Do this **before** [section 7](#7-clone-and-link), so `install_modules.ps1` writes the profile stub straight into OneDrive's Documents — the old stub and modules sync back there anyway |
| Encryption identity / encrypted files | `~\.config\age\`. Anything encrypted to the age key is **unrecoverable** without it |
| Broker / API credential files, trading working dir | Dotfiles and a dot-directory in `~`. Copy directly, never into this repo |
| `~\.aws\` | Profile config; re-authenticate |
| `~\.claude\` | Copy back `CLAUDE.md` (global instructions), `settings.json` and `projects\*\memory\` (per-project memory — valid only under the same account name). `sessions\`, `history.jsonl`, `.credentials.json` and `~\.claude.json` are per-machine; re-login instead |
| `~\Documents` (local) | Notes written by tools that hardcode `~\Documents`, *not* the OneDrive-redirected one. Copy back, or into OneDrive's Documents if you'd rather have them synced |
| `~\Downloads` | Kept for its few personal exports |
| osu! lazer | Data stays on the external SSD at `E:\osu`. Before the first launch, put `storage.ini` (`FullPath = E:\osu`) and `framework.ini` back in `%APPDATA%\osu\`. The SSD must be E: ([section 3.7](#37-first-login)) |
| Skyrim saves and INIs | `Documents\My Games\` — in OneDrive, so they sync back |
| Shell history | PSReadLine's `ConsoleHost_history.txt` and zoxide's `db.zo` — optional, same paths |

**Regenerate rather than copy:** `~\scoop\apps`, `~\.rustup`, `~\.cargo`,
`%LOCALAPPDATA%\nvim-data` (lazy.nvim and mason rebuild it), `~\.cache`,
`~\.prettierd`, `~\.local`, and every app's cache dir.

---

## 13. Known gotchas

**OneDrive folder backup moves `$PROFILE`.** The old install had OneDrive
backing up Desktop, Documents and Pictures, so its profile stub and PSGallery
modules are in OneDrive. Turning that backup on again moves Documents and the
stub with it, and the old modules come back alongside the ones
`install_modules.ps1` installed — harmless. If pwsh starts with no config,
check `$PROFILE` and re-run `install_modules.ps1`.

**OneDrive's Desktop folder is named `桌面`.** It was created while the UI was
Chinese. On the 2026-10 LTSC install, Desktop backup reused it directly. If a
separate `Desktop` folder ever appears next to it, move the files over.

**Drive letters can change.** The fresh install assigns letters in discovery
order, and the Ventoy stick can take E: before the SSD. Fix them in Disk
Management before reinstalling apps that store paths into them.

**`profile.ps1` has no guards.** Every tool it calls must be on PATH or pwsh
prints errors on every launch. If it does, the missing package is in the
[section 6](#6-packages-scoop) table.

**Windows Terminal reads settings from scoop's persist dir.** The scoop build
runs in portable mode, so it reads
`~\scoop\persist\windows-terminal\settings\settings.json`, not the Store
package's `LocalState` — `symlinks.windows` links only the scoop path. If WT
comes up unthemed, Settings → Open JSON file shows the path it actually reads.

**Shells started outside Windows Terminal open in conhost.** The scoop build
can't be the default terminal, so pwsh launched from the Run dialog, Flow
Launcher or a double-clicked script gets conhost, where oh-my-posh glyphs show
as boxes. `wt` and GlazeWM's `alt+enter` are unaffected. For an "Open in
Terminal" context menu, run
`reg import "$HOME\scoop\apps\windows-terminal\current\install-context.reg"`.

**SMB defaults are stricter on Enterprise.** 24H2 requires SMB signing, and
Enterprise turns off insecure guest logons. The old install already required
signing and the share worked; it also allowed guest logons, which doesn't
matter as long as Z: is mapped with a user name ([section 10](#10-network-share-and-password-database)).

---

## 14. Verification

```powershell
# in a new Windows Terminal tab — should open pwsh with the gruvbox prompt
Get-Item $HOME\.gitconfig, $HOME\.config\git\ignore, $LOCALAPPDATA\nvim, $HOME\.glzr\glazewm\config.yaml,
    $HOME\scoop\persist\windows-terminal\settings\settings.json | Select-Object FullName, LinkType, Target
which fzf fd rg bat zoxide yazi delta less gitui nvim mpv tree-sitter cc node cargo
```

Then:

- `nvim` — lazy.nvim installs plugins on first launch; `:checkhealth` after
  (tree-sitter-manager finds `tree-sitter`, `git` and `cc`), and `:Mason` shows
  all 18 packages installed
- `gitui` in a repo — gruvbox theme, vim keys
- `y` — yazi opens with the gruvbox theme, previews render (image, PDF,
  video), and the shell follows its cwd on quit
- `keys` — opens `powershell/cheatsheet.md`
- `music` — playlist picker comes up
- `alt+enter` — GlazeWM opens a terminal; Zebar bar visible
- `ctrl+printscreen` — ShareX's region overlay covers the whole screen (not
  tiled by GlazeWM); the capture lands on the clipboard and in
  `~\scoop\persist\sharex\ShareX\Screenshots\`
- `m` in Flow Launcher — Music plugin lists playlists
- `git commit` on a scratch change, then `git log --show-signature`
- Caps Lock acts as Esc; `Win+Space` switches to Microsoft Pinyin
- Settings → Privacy & security → Diagnostics & feedback says some settings are
  managed by your organization, and `Get-Service DiagTrack` shows Stopped
- Z: opens and KeePassXC unlocks the database
- osu! lazer shows your beatmaps
- Reboot into Arch: Nebula mounts read-write, clock is correct
