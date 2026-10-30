# Security

What each machine needs so that losing it, or taking it out of the house, costs
as little as possible. The other runbooks point here for these steps; this one
says what to set, why, and how to check it.

A machine plays one of two roles, and the role decides what applies:

- **Laptop**: it leaves home, so it can be lost or stolen, and it joins
  networks you don't control. Today that's the Macs.
- **Desktop**: it stays home, so the risks are a burglary, the ports the router
  forwards to it, and the other devices on the home network. Today that's the
  Arch/Windows dual-boot box.

Each section has the steps for macOS, Windows and Arch, so a laptop running
Windows or Linux later follows the laptop parts for its OS. The iPhone has a
runbook of its own, IPHONE.md, since little of this applies to it as written.

| Section | Laptop | Desktop |
|---|---|---|
| [1. Screen lock and Find My](#1-screen-lock-and-find-my) | Yes | Screen lock |
| [2. Firewall](#2-firewall) | Yes | Yes |
| [3. What listens on the network](#3-what-listens-on-the-network) | Yes | Yes |
| [4. Updates](#4-updates) | Yes | Yes |
| [5. SSH keys](#5-ssh-keys) | Yes | Yes |
| [6. aria2's RPC secret](#6-aria2s-rpc-secret) | Yes | Yes |
| [7. Helium and KeePassXC](#7-helium-and-keepassxc) | Yes | Yes |
| [8. The router](#8-the-router) | | Yes |
| [9. Untrusted networks](#9-untrusted-networks) | Yes | |
| [10. If a machine is lost or stolen](#10-if-a-machine-is-lost-or-stolen) | Yes | Yes |

The monthly update checks the settings it can read
([section 11](#11-what-the-monthly-update-checks)).

---

## 1. Screen lock and Find My

**macOS.**

- Require the password as soon as the screen locks: System Settings → Lock
  Screen → *Require password after screen saver begins or display is turned
  off* → **Immediately**. `sysadminctl -screenLock status` then says
  `screenLock delay is immediate`; the monthly update checks it. ⌃⌘Q locks it
  when you walk away
- **Find My Mac**: System Settings → Apple Account → iCloud → Find My Mac. A
  lost Mac can then be located, locked and erased from icloud.com/find or
  another Apple device, and Activation Lock stops a thief from setting it up
  as theirs

**Windows.**

- Settings → Accounts → Sign-in options → *If you've been away, when should
  Windows require you to sign in again?* → **Every time**. A Windows Hello PIN
  keeps it quick, and Win+L locks
- **Find my device**: Settings → Privacy & security → Find my device. It needs
  a Microsoft account, so a local account, like the desktop's, can't use it:
  fine for a desktop, and a reason to sign a Windows laptop in to one

**Linux (Hyprland).** hypridle locks the session with hyprlock. Check that
its config, which is in the `~/.dotfiles.git` bare repo, locks after a few
idle minutes and before sleep: a `before_sleep_cmd` running
`loginctl lock-session`, and a `lock_cmd` that starts hyprlock. There's no Find
My.

---

## 2. Firewall

Anything that listens on the network can be reached by every device on the same
network: a café's or a hotel's, and at home the phones, TVs and guests on your
Wi-Fi. A firewall turns away incoming connections except the ones you allow.
It doesn't affect connections you start yourself.

**macOS.**

```sh
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on   # no answer to pings and port scans
```

Or System Settings → Network → Firewall, with stealth mode under Options. It
lets Apple's own software and signed apps accept connections by default, which
is why AirPlay Receiver needs turning off on its own
([section 3](#3-what-listens-on-the-network)). macOS may ask whether `aria2c`
can accept incoming connections: allowing it lets BitTorrent peers connect in,
and refusing still downloads, from fewer peers. The monthly update checks both
settings.

**Windows.** Defender Firewall is on for all three network profiles by
default; keep it that way. Windows marks a network you join as Public unless
you say otherwise. Leave every network so, home included: Private opens Network
Discovery, Remote Assistance, casting and mDNS to every device on the network,
and nothing here needs them. The network share works on Public, since the
machine is the one connecting. `Get-NetConnectionProfile` shows each network's
profile.

`aria2/windows/add_firewall_rules.ps1` opens 6881–6999 for every profile,
Public included, which the desktop needs: the router forwards them to it
([section 8](#8-the-router)). A laptop gets no forward, so on one the rules
would only let in peers on other networks, a café's among them. Skip the script
there, or remove its rules, elevated:

```powershell
Remove-NetFirewallRule -DisplayName Allow-P2P-TCP, Allow-P2P-UDP
```

`Get-NetFirewallProfile | Select-Object Name, Enabled` lists the profiles, and
the monthly update checks them.

**Arch.** Nothing filters by default. ufw, with only aria2's BitTorrent ports
open:

```sh
sudo pacman -S ufw
sudo ufw default deny incoming
sudo ufw allow 6881:6999/tcp    # aria2: BitTorrent peers, which the router forwards here
sudo ufw allow 6881:6999/udp    # aria2: DHT
sudo systemctl enable --now ufw.service
sudo ufw enable
sudo ufw status verbose
```

It isn't in `pkglist.arch`, which holds only what this repo's configs need. The
monthly update checks that it's enabled and on. Two things to know:

- Docker writes rules of its own for published ports, ahead of ufw's, so
  `-p 8080:80` is open to the network whatever ufw says. Publish to loopback
  instead: `-p 127.0.0.1:8080:80`
- Something other devices at home should reach, like Steam's Remote Play, needs
  its ports allowed from the home network only, for example
  `sudo ufw allow from 192.168.1.0/24 to any port 27036 proto tcp`, with your
  network's range from `ip -4 addr`

---

## 3. What listens on the network

The firewall is the backstop. Better still is nothing listening that doesn't
need to.

**macOS.**

- **AirPlay Receiver off**: System Settings → General → AirDrop & Handoff. It
  listens to the whole network on ports 5000 and 7000, and the firewall lets
  it through as Apple software. In 2025, researchers found bugs in it
  ("AirBorne") that let a device on the same network run code on a Mac without
  a click; Apple fixed them in macOS 15.4. The monthly update checks it
- **AirDrop**: Contacts Only, the default, or off
- **Sharing**: System Settings → General → Sharing, everything off that you
  don't use: File Sharing, Screen Sharing, Remote Login, Remote Management
- `rapportd` listening is expected: it's Handoff and Universal Clipboard, and
  answers only devices signed in to your Apple Account

What's reachable from the network:

```sh
sudo lsof -nP -iTCP -sTCP:LISTEN | grep -Ev '127\.0\.0\.1|\[::1\]'
```

**Windows.**

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalAddress -NotIn '127.0.0.1', '::1' |
    Sort-Object LocalPort -Unique |
    Select-Object LocalAddress, LocalPort, @{ n = 'Process'; e = { (Get-Process -Id $_.OwningProcess).Name } }
```

Windows' own services (ports 135, 445 and so on) show up here; the Public
profile keeps them off the network.

**Arch.**

```sh
sudo ss -tulpn | grep -Ev '127\.0\.0\.|\[::1\]'
```

**On all three**, expect aria2's BitTorrent ports, 6881–6999, while a torrent
is active, and its RPC on 6800, on loopback only: `rpc-listen-all=false` in
`aria2.conf` keeps it there. Keep that line, and never forward 6800 on the
router.

**The network share's name.** The public DNS server the router hands out
doesn't know the share's name, so to find it, a machine asks the whole network
and takes the first answer. Any device there can give it: a TV or phone with
malware, a guest's laptop. The machine then sends that device the share's
login, as a challenge-response it can try to crack offline: a long password
keeps it out of reach, a short one doesn't. Windows asks at each sign-in, to
reconnect Z:, and again every few minutes while Z: is in use. It requires SMB
signing, so an impostor can't pose as the share itself, only collect the login.
Put the name in the hosts file, at the share's address (the router's, for its
USB share), and turn off LLMNR and NetBIOS, which ask the network for any name
DNS doesn't know.

On Windows, elevated, then restart:

```powershell
# <share-host> as in \\<share-host>\<share>; the router's address is (Get-NetRoute -DestinationPrefix 0.0.0.0/0).NextHop
Add-Content "$env:SystemRoot\System32\drivers\etc\hosts" "`n<router-ip>`t<share-host>"
# LLMNR off, then NetBIOS off on every adapter
$k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
if (-not (Test-Path $k)) { New-Item $k | Out-Null }
Set-ItemProperty $k EnableMulticast 0 -Type DWord
Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces |
    ForEach-Object { Set-ItemProperty $_.PSPath NetbiosOptions 2 -Type DWord }
```

If the router's address changes, so must that line. An adapter added later
starts with NetBIOS on; the monthly update flags it once it's connected, and
LLMNR on, or a mapped share's name missing from the hosts file.

macOS and Arch ask the network the same way, and the same line in `/etc/hosts`
covers the share: `echo '<router-ip> <share-host>' | sudo tee -a /etc/hosts`,
then connect by that name.

On macOS, the SMB client asks the network only for a name the hosts file and
DNS don't know, and the Keychain files the share's password under the name, so
it keeps finding it. The counterpart of NetBIOS off on Windows is
`/etc/nsmb.conf`, which covers every account on the Mac and doesn't exist by
default: `port445=no_netbios` stops the asking, and port 139 with it,
`protocol_vers_map=6` leaves SMB 2 and 3, and `signing_required=yes` lets no
device in between change what's read from a share.

```sh
printf '[default]\nport445=no_netbios\nprotocol_vers_map=6\nsigning_required=yes\n' | sudo tee /etc/nsmb.conf
```

A share already open keeps its connection until it's ejected. `netbiosd` still
listens on UDP 137 and 138, but with File Sharing off it doesn't answer for the
Mac. The monthly update flags a mounted share's name missing from `/etc/hosts`,
or a line above missing from `/etc/nsmb.conf`.

On Arch, systemd-resolved does the asking, by LLMNR, which is on by default.
A drop-in turns it off:

```sh
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nLLMNR=no\n' | sudo tee /etc/systemd/resolved.conf.d/llmnr.conf
sudo systemctl restart systemd-resolved
```

`resolvectl status` then shows `-LLMNR`. It still asks by mDNS, but only for
names ending in `.local`. The share's line in `/etc/fstab` mounts it by
address, `//<router-ip>/<share>`, so the mount looks up no name. Linux's SMB
client signs only when the server requires it, and the router's share
doesn't, so add `sign` to that line's options, then
`sudo systemctl daemon-reload` and `sudo systemctl stop` on its mount point,
which unmounts it and leaves the automount in place: the next access mounts it
signed, and `/proc/fs/cifs/DebugData` shows its session as signed.

The share's login goes in a file only root can read, which the line's
`credentials=` option names. Root does the mount, so nothing running as you
needs to read it:

```sh
sudo install -d -m 700 /etc/samba/credentials
sudoedit /etc/samba/credentials/tp-share    # username=, password= and domain= lines
sudo chmod 600 /etc/samba/credentials/tp-share
```

The monthly update flags LLMNR on, an SMB line in `/etc/fstab` without
`sign`, or a share whose login you can read without root.

---

## 4. Updates

Most attacks use holes that already have a fix. The monthly update is the
floor (MIGRATION.md section 8, MIGRATION.arch.md section 10,
MIGRATION.windows.md section 15); these keep the gaps shorter.

- **macOS**: System Settings → General → Software Update → Automatic Updates,
  all on. *Install Security Responses and system files* matters most: it brings
  urgent security fixes and XProtect's malware definitions without waiting for
  you. The monthly update checks it
- **Windows**: Windows Update installs security updates on its own, and Defender
  updates its definitions daily. Keep Defender's real-time protection on; the
  monthly update checks it. MIGRATION.windows.md section 5.3 turns off sample
  submission, not protection
- **Arch**: nothing updates on its own, so the monthly update is the only
  patching; on a laptop, run `paru -Syu` weekly. `arch-audit` (`pacman -S
  arch-audit`) lists installed packages with known vulnerabilities, and
  `arch-audit -u` the ones with a fix waiting
- **Helium**: browsers get security fixes most weeks. On macOS Helium updates
  itself, but on Arch and Windows only the package manager updates it, so when
  Chromium ships a security fix, don't wait for the month: `paru -Syu`, or
  `scoop update helium`

---

## 5. SSH keys

Without a passphrase, whoever gets a copy of `~/.ssh/github` and
`signing_key` can push to your repos and sign commits as you: malware, a
compromised package, or whoever ends up with a lost laptop. A passphrase makes
a copy useless on its own, and an agent keeps it to one prompt per login, or
none. Adding one keeps the key, so GitHub needs nothing:

```sh
ssh-keygen -p -f ~/.ssh/github      # then signing_key, and any other private key there
```

Commit signing needs the agent. git signs with `ssh-keygen -Y sign`, which uses
the key in the agent if it's there, and otherwise asks for the passphrase in
the terminal: on every commit, and where there's no terminal, as for a commit
from a script or Claude Code, it fails. So each OS below loads the signing key
into the agent at login.

**macOS.** The login Keychain keeps the passphrases. Add to the top of
`~/.ssh/config`:

```
# Arch and Windows get a copy of this file, and their ssh doesn't know UseKeychain
IgnoreUnknown UseKeychain
Host *
    UseKeychain yes
```

Then, once, which asks for each passphrase and saves it in the Keychain:

```sh
ssh-add --apple-use-keychain ~/.ssh/github ~/.ssh/signing_key
```

The agent starts empty after a restart. This line in `~/.zshrc.local` loads
the keys from the Keychain, without asking, when the signing key isn't in the
agent yet. `-q` doesn't silence *No identity found in the keychain*, which it
says while the Keychain has no passphrase, hence the `2>/dev/null`:

```sh
ssh-add -T ~/.ssh/signing_key.pub 2>/dev/null || ssh-add --apple-load-keychain -q 2>/dev/null
```

**Arch.** First an agent, if none runs: `ssh-add -l` saying *Could not open a
connection* means none. Arch's openssh has a user unit for one:

```sh
systemctl --user enable --now ssh-agent.service
```

Then, in `~/.zshrc.local`, point at it:

```sh
export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket
```

The passphrases are in KeePassXC's Login database, the keychain (section 7),
which adds both keys to the agent when it unlocks, as the Mac's Keychain does.
In KeePassXC:

- Settings → SSH Agent: turn on *Enable SSH Agent integration*, and set
  *SSH_AUTH_SOCK override* to `/run/user/1000/ssh-agent.socket`. KeePassXC
  starts from Hyprland, which doesn't set the variable
- In Login, an entry per key in its `SSH` group, outside the group apps can
  ask for: the passphrase as its password, and on its SSH Agent tab, the key
  as an external file, *Add key to agent when database is opened/unlocked*
  on, and *Remove key from agent when database is closed/locked* off, so the
  keys stay through a screen lock

Until Login is unlocked the agent is empty: a signed commit fails, and ssh
asks for the passphrase itself.

Any other key goes into the agent the first time ssh uses it, asking once,
with this at the top of `~/.ssh/config`:

```
Host *
    AddKeysToAgent yes
```

**Windows.** The OpenSSH agent service is off by default. Keys added to it stay
through restarts, stored encrypted for your account, so each one is added once:

```powershell
sudo pwsh -NoProfile -Command 'Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent'
ssh-add $HOME\.ssh\github $HOME\.ssh\signing_key
```

Git for Windows runs its own ssh and ssh-keygen, which can't reach that
service, so point git at Windows' own, in `git/gitconfig.windows`'s `[core]`
and `[gpg "ssh"]` sections:

```
[core]
	sshCommand = C:/Windows/System32/OpenSSH/ssh.exe
[gpg "ssh"]
	program = C:/Windows/System32/OpenSSH/ssh-keygen.exe
```

Then check with `git fetch` and a signed commit, as in MIGRATION.windows.md
section 8.

The passphrase travels with the key file, so copying keys to a new machine
works as before; only the agent setup above is per machine.

---

## 6. aria2's RPC secret

aria2 takes orders on port 6800, from Aria2 Explorer and AriaNg: what to
download, and where to save it. It listens on loopback only, but a web page in
the browser can send requests to loopback too. Without a secret, a page could
have aria2 save a file anywhere you can write, like a launch agent or a shell
startup file, which is as good as running code as you. Recent Chromium asks
before a site talks to loopback, which likely stops it in Helium; the secret
stops it everywhere.

Each machine has its own secret, the `rpc-secret=` line in the installed
`aria2.conf`; the repo's can't hold one, since the repo is public. The install
scripts add a random one, keep the one there on a rerun, and leave the file
readable only by you. The monthly update
keeps the line when it rewrites the file, as it keeps the trackers, and flags a
config without one. For an install from before the scripts did this, on macOS
and Arch:

```sh
conf=~/.config/aria2/aria2.conf
chmod 600 $conf
grep -q '^rpc-secret=' $conf || echo "rpc-secret=$(openssl rand -hex 16)" >>$conf
launchctl kickstart -k gui/$UID/com.aria2     # macOS
systemctl --user restart aria2.service        # Arch
```

On Windows:

```powershell
$conf = "$HOME\.config\aria2\aria2.conf"
if (-not (Select-String -Quiet '^rpc-secret=' $conf)) {
    Add-Content $conf ('rpc-secret=' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLower())
}
Stop-Process -Name aria2c; Start-Sleep 2; Start-ScheduledTask Aria2
```

Then give the secret to the frontends. `sed -n 's/^rpc-secret=//p'
~/.config/aria2/aria2.conf` prints it; on Windows,
`(Select-String '^rpc-secret=(.*)' $conf).Matches.Groups[1].Value`.

- **Aria2 Explorer**: its options, the RPC settings of the `localhost:6800`
  server, the secret field
- **AriaNg**: AriaNg Settings → RPC → *Aria2 RPC Secret Token*

A download from Helium should then still reach aria2. Anything else that
calls the RPC sends the secret as its first parameter, `"token:<secret>"`, as
the runbooks' checks do.

---

## 7. Helium and KeePassXC

**Helium** gets two security settings from `helium/policies.json`, on every OS:

- `HttpsOnlyMode: force_enabled`, which is *Always use secure connections*: it
  warns before loading any page over plain HTTP, which whoever runs the network
  can read and change. You can still go on to the page
- `DnsOverHttpsMode: secure`, with Google's server: its lookups go encrypted to
  dns.google and never fall back to plain DNS, which a network can read and
  answer falsely. Where dns.google is blocked, as in mainland China, Helium
  can't look anything up unless Clash Verge Rev is on (MIGRATION.md
  section 3): its system proxy takes the lookups over, and TUN mode carries
  them to dns.google

After a change to the file, macOS needs `helium/apply-policies.sh` and Windows
`helium\apply-policies.ps1`, elevated; on Arch the policy file is a link to it.
The monthly update flags a difference, and `helium://policy` lists them. Keep
the extensions to the two the policy installs: an extension can read every page
it has access to.

**KeePassXC.**

- Settings → Security: keep *Lock databases when session is locked or lid is
  closed* on, the default. *Lock databases after inactivity of*, off by
  default, is on everywhere, at an hour: KeePassXC counts only what you do in
  its own window, and on Arch it locks the Login database too, the keychain,
  which takes the SSH keys out of the agent. It's in
  `keepassxc/keepassxc.ini`, the settings `keepassxc/apply-settings.sh` and
  `apply-settings.ps1` merge in on every machine
- The master password protects every copy: this machine's, the one on
  tp-share, and the backups. Make it long. A key file or a hardware key adds a
  second factor, if you want one
- KeePassXC-Browser fills a login only on the site it was saved for. When it
  doesn't offer one where it normally would, check the address bar before
  typing anything: you may be on a copy of the site
- **Arch**: KeePassXC doubles as the keychain, the Mac's Keychain and
  Windows' Credential Manager, which Arch doesn't come with. It's a database
  of its own on the machine, Login, `~/.local/share/keepassxc/login.kdbx`,
  with its own password. Apps keep their secrets in its `Secret Service`
  group, through KeePassXC's Secret Service, and the SSH keys' passphrases are
  in its `SSH` group (section 5), so make its password as strong as theirs.
  Any program you run can ask the Secret Service for what it holds, so that
  group is the only one exposed there: Login's Database Settings → Secret
  Service Integration exposes it alone, and the main database's is *Don't
  expose this database*. KeePassXC starts at login with Login locked in the
  tray, and asks for its password when an app first needs a secret; a
  fingerprint login gives it nothing to unlock with (MIGRATION.arch.md
  section 2)

---

## 8. The router

The desktop sits behind it, and so do the laptops when they're home.

- Forward only what the desktop needs: 6881–6999, TCP and UDP, for aria2. A
  forward goes to one address, so the desktop's; a laptop downloads without
  one, from fewer peers. Never forward 6800, aria2's RPC, and nothing for SMB,
  RDP or SSH
- Turn UPnP off: it lets any device on the network open ports to the internet
  for itself
- **IPv6**: when the ISP provides it, every machine at home gets addresses the
  internet can reach directly: the ones starting with 2 or 3 (Windows:
  `Get-NetIPAddress -AddressFamily IPv6`; macOS: `ifconfig`; Arch: `ip -6
  addr`). No shared address hides them behind the router, as IPv4's does, so
  its IPv6 firewall is what drops the connections nobody at home started:
  check it's on, in the router's IPv6 or security settings. Without it, each
  machine's own firewall is all that's left, and the desktop's lets in aria2's
  ports, Windows' update sharing (Delivery Optimization, 7680) and any app it
  was once told to allow. To test it, run an online IPv6 port scan of the
  desktop's address while aria2 has a torrent active, on aria2's port in
  6881–6999 (`Get-NetTCPConnection -State Listen -OwningProcess (Get-Process aria2c).Id`):
  filtered means the router stops it, open means it doesn't. The forward
  above is IPv4 only, so IPv6 peers can't connect in; they still connect out
- Keep its firmware updated, change its admin password, and turn off
  administration from the internet
- Wi-Fi: WPA3, or WPA2/WPA3 for older devices, with a long passphrase. A guest
  network keeps visitors and smart-home devices away from your machines

---

## 9. Untrusted networks

Cafés, hotels, airports, conferences. HTTPS protects the content of almost
everything, but on an open network, anyone nearby can see which sites you
visit, change what goes over plain HTTP, answer DNS falsely, or run a copy of
the network, and every device on it can try the ports the laptop listens on.
Sections 2, 3 and 7 set the laptop up for this; the rest is here.

**A VPN on every laptop.** Whatever its OS, a laptop has Proton VPN installed
and signed in before it leaves home, and on a network you don't control, it's
on from the moment you're past the sign-in page. It carries everything, DNS and
apps that don't use HTTPS included, encrypted to its server. A desktop never
joins such a network, so it doesn't need one. Your phone's hotspot is the
exception: that network is yours.

On macOS, `mac/vpn-reminder.sh` reminds you. When the Mac is on a network you
haven't trusted and its traffic, IPv4 or IPv6, isn't going through a tunnel,
it shows an alert: on joining such a network, and again each time the VPN
drops. Any VPN counts, Clash Verge Rev's TUN mode included, but it can't tell
whether a tunnel encrypts everything: in Rule mode, Clash passes. Trust your
own networks, home and your phone's hotspot, by running
`mac/vpn-reminder.sh --trust` once on each. `bootstrap.sh` registers its launch
agent; on an older install, `mac/vpn-reminder.sh --register`. A Windows or
Linux laptop has no reminder yet.

- **Proton VPN Free**: no data cap and no ads, one connection at a time, to
  a server in one of a few countries, which it picks for you. Enough for
  public Wi-Fi. macOS: `brew install --cask protonvpn` (MIGRATION.md section
  3); Windows: the installer from protonvpn.com; Arch: `sudo pacman -S
  proton-vpn-gtk-app`
- **Clash Verge Rev**, for mainland China, where most VPNs are blocked
  (MIGRATION.md section 3), is only a client: it needs a proxy server you pay
  for. With one, in **Global** mode with TUN on, every connection goes
  encrypted to that server. In Rule mode, the sites it sends DIRECT skip it

Avoid free VPN apps from companies you don't know: a VPN sees everything the
café could have, and they tend to pay for themselves by selling it.

**Encrypted DNS.** A network hands out its own DNS server, and the laptop asks
it in plain text, so whoever runs the network reads every name the laptop looks
up and can answer falsely. Helium encrypts its own lookups (section 7). For the
rest, on macOS, `mac/dns-over-https.sh` builds a configuration profile that
sends every lookup to Cloudflare over HTTPS, whatever server the network hands
out, and opens it: install it in System Settings → General → Device
Management. With `--iphone`, it sends the same profile to the iPhone
(IPHONE.md section 1.4). The desktop uses TLS instead (MIGRATION.arch.md section 1,
MIGRATION.windows.md section 5.6), but a network can block TLS's port, 853,
and not HTTPS's, which the web uses. While Proton VPN is on, macOS asks
Proton's server, through the tunnel, instead. At home the profile changes
little: Cloudflare's servers, which the router hands out, tell macOS how to
reach them encrypted, and it does so by itself.

A network's sign-in page still loads: macOS asks the network's own server for
the names its sign-in window needs, and only those. Otherwise the profile never
falls back to plain DNS, so where nothing resolves, as in mainland China, where
Clash Verge Rev's TUN mode takes the lookups instead, set **Cloudflare** to
Disabled in System Settings → Network → VPN & Filters, and back to Enabled
when you leave. The monthly update lists it until you do.

**Habits.**

- Check the network's name with the staff: anyone can broadcast a copy of an
  open network's name
- On its sign-in page, give at most a room number, an email address or your
  agreement to the terms, never a password or a card number
- Never click through a certificate warning
- When KeePassXC doesn't offer a login where it normally would, check the
  address bar before typing
- Don't open tp-share there: anyone on the network can answer for its name
  and collect the login attempt to crack offline. Open it only at home
- When you leave, forget the network (macOS: System Settings → Wi-Fi, ⋯ next to
  it → Forget This Network; Windows: Settings → Network & internet → Wi-Fi →
  Manage known networks). Otherwise the laptop joins any network with that
  name later, anywhere. On macOS, the monthly cleanup catches what you miss,
  and what iCloud syncs in from your other Apple devices: it offers to forget
  every network not listed in `~/.config/wifi/keep`, one name per line, which
  stays out of the repo, since it's public. List home and your phone's hotspot
  there on each Mac
- On Windows, leave it marked Public

---

## 10. If a machine is lost or stolen

In this order:

1. **Lock or erase it**: Find My (icloud.com/find, or another Apple device),
   or account.microsoft.com/devices
2. **Revoke its SSH keys**: GitHub → Settings → SSH and GPG keys, its
   authentication key and its signing key. Each machine has keys of its own,
   so the others keep theirs. GitHub lists each key by title and fingerprint,
   and a commit made on the lost machine shows its signing key's:
   `git log -1 --format=%GF <commit>`. The machine that replaces it gets new
   keys: add the new signing key's line to `~/.ssh/allowed_signers` and keep
   the old one, or the lost machine's past commits stop verifying
3. **Sign it out**: your Apple Account's device list, Google (Security → Your
   devices), GitHub (Settings → Sessions), Discord, Proton (account.proton.me,
   its sessions), and the brokers
4. **Rotate what was on it in plaintext**: the broker and API keys, AWS
   credentials, and Clash Verge Rev's subscription URL, which is a credential
   itself: reset it with the provider
5. **KeePassXC**: if the master password is weak, or the machine was taken
   unlocked, change it, then the passwords that matter most
6. **The age key**: treat everything encrypted to it as readable by whoever has
   the machine: make a new key and encrypt again to it

---

## 11. What the monthly update checks

It lists what isn't as set under **Security** in what's left at the end:

- **macOS** (`mac/steps/80-settings.zsh`): the password as soon as the screen
  locks, the firewall and stealth mode, AirPlay Receiver off, *Security
  Responses and system files* on, section 3's share name: each mounted
  share's name in `/etc/hosts` and `/etc/nsmb.conf`'s three lines; and
  section 9's DNS over HTTPS profile: installed, matching
  `mac/dns-over-https.sh`, and Enabled
- **Windows** (`powershell/steps/80-settings.ps1`): the firewall on for all
  three profiles, Defender's real-time protection, section 3's share name:
  each mapped share's name in the hosts file, LLMNR off, NetBIOS off on each
  connected adapter, and an SMB client that requires signing, refuses guest
  logins and has no SMB 1; and DNS over TLS on, DNS over HTTPS off, and a TLS
  host with no plain fallback for each DNS server a connected adapter has
  (MIGRATION.windows.md section 5.6)
- **Arch** (`arch/steps/80-settings.zsh`): ufw enabled and on, section 3's
  LLMNR off, and `sign` on each SMB share in `/etc/fstab` with its login
  readable only by root, and DNS over TLS:
  systemd-resolved running, in strict mode globally and on each link with DNS
  servers, and `/etc/resolv.conf` pointing at it (MIGRATION.arch.md section 1);
  and section 7's KeePassXC Secret Service on, and no gh token in plain text
  in `~/.config/gh/hosts.yml`

On all three, more come up under other headings: a missing `rpc-secret=`
in aria2's config under **aria2** (`51-aria2`), and under **Reset**, a Helium
policy that doesn't match `policies.json`, the HTTPS and DNS ones included,
and a KeePassXC setting that isn't `keepassxc/keepassxc.ini`'s, the inactivity
lock included. And on macOS, the cleanup (`mac/steps/60-wifi.zsh`) lists the Wi-Fi
networks not in `~/.config/wifi/keep` under **Security** when you don't let it
forget them, or when there's no such file (section 9).

Not checked: Find My, the SSH passphrases, KeePassXC's settings beyond `keepassxc.ini` and Arch's Secret Service, a laptop's
VPN and the router, its IPv6 firewall included. A security setting you make by hand that a command can read
goes in the platform's `80-settings`, with the others.
