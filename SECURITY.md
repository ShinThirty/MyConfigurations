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
Windows or Linux later follows the laptop parts for its OS.

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
you say otherwise, which is right for anywhere but home; mark your home network
Private (Settings → Network & internet → Wi-Fi → its properties).
`aria2/windows/add_firewall_rules.ps1` opens 6881–6999 for every profile: right
for the desktop, but on a laptop limit them to home, elevated:

```powershell
Set-NetFirewallRule -DisplayName Allow-P2P-TCP, Allow-P2P-UDP -Profile Private
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

`~/.ssh/github` and `signing_key` have no passphrase. Whoever gets a copy of
the files can push to your repos and sign commits as you: malware, a
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

Then, in `~/.zshrc.local`, point at it, and add the signing key in the first
terminal after login, which asks for its passphrase once:

```sh
export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket
ssh-add -T ~/.ssh/signing_key.pub 2>/dev/null || ssh-add ~/.ssh/signing_key
```

The other keys go into the agent the first time ssh uses them, asking once,
since `~/.ssh/config` has `AddKeysToAgent yes`.

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
scripts add a random one, and keep the one there on a rerun. The monthly update
keeps the line when it rewrites the file, as it keeps the trackers, and flags a
config without one. For an install from before the scripts did this, on macOS
and Arch:

```sh
conf=~/.config/aria2/aria2.conf
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
  closed* on, the default. On a laptop, also turn on *Lock databases after
  inactivity of*, say 900 seconds; it's off by default
- The master password protects every copy: this machine's, the one on
  tp-share, and the backups. Make it long. A key file or a hardware key adds a
  second factor, if you want one
- KeePassXC-Browser fills a login only on the site it was saved for. When it
  doesn't offer one where it normally would, check the address bar before
  typing anything: you may be on a copy of the site

---

## 8. The router

The desktop sits behind it, and so do the laptops when they're home.

- Forward only what the desktop needs: 6881–6999, TCP and UDP, for aria2. A
  forward goes to one address, so the desktop's; a laptop downloads without
  one, from fewer peers. Never forward 6800, aria2's RPC, and nothing for SMB,
  RDP or SSH
- Turn UPnP off: it lets any device on the network open ports to the internet
  for itself
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
  name later, anywhere
- On Windows, leave it marked Public

---

## 10. If a machine is lost or stolen

In this order:

1. **Lock or erase it**: Find My (icloud.com/find, or another Apple device),
   or account.microsoft.com/devices
2. **Revoke the SSH keys**: GitHub → Settings → SSH and GPG keys (the
   authentication key, and the signing key). Every machine has copies of the
   same files, so this means new keys everywhere. Add the new signing key's
   line to `~/.ssh/allowed_signers`, keeping the old one, or past commits stop
   verifying
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
  locks, the firewall and stealth mode, AirPlay Receiver off, and *Security
  Responses and system files* on
- **Windows** (`powershell/steps/80-settings.ps1`): the firewall on for all
  three profiles, and Defender's real-time protection
- **Arch** (`arch/steps/80-settings.zsh`): ufw enabled and on

On all three, two more come up under other headings: a missing `rpc-secret=`
in aria2's config under **aria2** (`51-aria2`), and a Helium policy that
doesn't match `policies.json`, the HTTPS and DNS ones included, under
**Reset**.

Not checked: Find My, the SSH passphrases, KeePassXC's settings, a laptop's
VPN and the router. A security setting you make by hand that a command can read
goes in the platform's `80-settings`, with the others.
