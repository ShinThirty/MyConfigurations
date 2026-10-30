# iPhone

Keeping the iPhone safe and up to date. It isn't a computer: nothing from this
repo runs on it, and a computer can read only a few of its settings, so most of
this is done by hand in Settings. What a computer can read, the Mac reads over
USB each month ([section 2](#2-the-monthly-check)).

In SECURITY.md's terms the phone is a laptop, only more so. It's always with
you, so it's the device most likely to be lost or stolen; it joins more
networks than the Macs do; and other accounts trust it: it gets their texted
codes, and its hotspot is the network the laptops trust (SECURITY.md
section 9).

- [1. Security](#1-security)
  - [1.1 Passcode and Face ID](#11-passcode-and-face-id)
  - [1.2 Find My and Stolen Device Protection](#12-find-my-and-stolen-device-protection)
  - [1.3 Updates](#13-updates)
  - [1.4 Networks](#14-networks)
  - [1.5 Configuration profiles and certificates](#15-configuration-profiles-and-certificates)
  - [1.6 Backups](#16-backups)
  - [1.7 If the phone is lost or stolen](#17-if-the-phone-is-lost-or-stolen)
- [2. The monthly check](#2-the-monthly-check)

---

## 1. Security

### 1.1 Passcode and Face ID

The passcode is what encrypts the phone's data: without one, whoever holds the
phone has all of it, and what depends on it is off, Stolen Device Protection
(1.2) and Apple Pay included.

- Settings → Face ID & Passcode → Turn Passcode On, or Change Passcode →
  Passcode Options. Six digits at least; a custom alphanumeric code is
  stronger, and with Face ID you rarely type it
- Face ID, in the same place, so the phone can lock often without costing you
  anything. Settings → Display & Brightness → Auto-Lock → **1 minute**
- Face ID & Passcode → Allow Access When Locked: turn off **Control Center**,
  so whoever takes the phone can't switch on Airplane Mode before you've marked
  it lost, and keep **USB Accessories** off, the default: once the phone has
  been locked for an hour, its port refuses anything but charging
- Type the passcode where nobody can watch: a thief who has seen it can do what
  Stolen Device Protection doesn't cover

The monthly check reads whether a passcode is set.

### 1.2 Find My and Stolen Device Protection

- **Find My**: Settings → your name → Find My → Find My iPhone, with *Find My
  network* and *Send Last Location* on. A lost phone can then be located, for a
  while even switched off, locked and erased from icloud.com/find or a Mac, and
  Activation Lock stops a thief from setting it up as theirs
- **Stolen Device Protection**: Settings → Face ID & Passcode → Stolen Device
  Protection, on. Thieves watch for the passcode, then take the phone: with the
  passcode alone, they could change your Apple Account password and lock you
  out of everything. With this on, away from places the phone knows as yours,
  it wants Face ID, with no passcode instead, to use saved passwords and cards
  or erase the phone, and makes you wait an hour, then Face ID again, to change
  the Apple Account password or the passcode, or turn off Find My or this
  protection. *Require Security Delay* → **Always** applies the hour at home
  too
- **SIM PIN**, for a physical SIM: Settings → Cellular → SIM PIN, starting from
  the carrier's default PIN; change it there. Without one, a thief puts your
  SIM in another phone and gets your texted codes. Three wrong tries lock the
  SIM until you have its PUK from the carrier. An eSIM stays in the phone,
  behind the passcode

### 1.3 Updates

- Settings → General → Software Update → Automatic Updates, everything on:
  iOS updates then install overnight while the phone charges, and urgent
  security fixes come between them
- When a new iOS comes out in September, Apple keeps shipping security updates
  for the previous one for a while, under *Also Available* in Software Update.
  Staying on it for a few months is fine, but only the newest iOS gets every
  fix
- Apps: Settings → Apps → App Store → App Updates, on. Delete the apps you no
  longer use: each one is more code that can have a hole. Section 2's
  `iphone/apps.py` lists them

The monthly check compares the phone's version with Apple's list of releases
for its model.

### 1.4 Networks

On a network you don't control, the phone faces what a laptop does (SECURITY.md
section 9), and gets the same answers.

- **Proton VPN**: the iOS app, signed in to the same account as the laptops,
  and on from the moment you're past the network's sign-in page. Proton VPN
  Free allows one connection at a time: when a Mac needs a network too, give it
  the phone's hotspot, which goes over cellular. Cellular needs no VPN: the
  carrier is a known party, not whoever runs the café
- **Shadowrocket**, for mainland China, where most VPNs are blocked: the
  phone's Clash Verge Rev (MIGRATION.md section 3). Like it, it's only a
  client, for the proxy server you pay for, which it reaches through the
  provider's subscription URL. It isn't in China's App Store, so it comes from
  an Apple Account of another region. iOS runs one VPN at a time, so there it
  takes Proton VPN's place. On a network you don't control, set its Global
  Routing to **Proxy**: every connection then goes encrypted to that server.
  In **Config**, the sites its rules send DIRECT skip it, as in Clash's Rule
  mode, and go out over the café's network as they are
- **Encrypted DNS**: the profile `mac/dns-over-https.sh` builds for the Macs
  works on the phone. On a Mac, with the phone connected and unlocked, run
  `mac/dns-over-https.sh --iphone`, then finish installing it on the phone in
  Settings → General → VPN & Device Management. With the VPNs off,
  one.one.one.one/help then says *Using DNS over HTTPS (DoH)*: Yes. It sends
  every lookup to
  Cloudflare over HTTPS, on Wi-Fi and cellular alike, and behaves as it does on
  the Mac: Proton's server takes over while the VPN is on, a network's sign-in
  page still loads, and it never falls back to plain DNS. Where nothing
  resolves, as in mainland China, set Settings → General → VPN & Device
  Management → DNS to Automatic, and back to Cloudflare when you leave:
  Shadowrocket answers the lookups once it's on, but it needs the network's
  own server to connect. After a change to the script, run it again; the new
  profile replaces the old one
- **Wi-Fi**: on a network you don't control, keep *Private Wi-Fi Address* on
  Rotating (the ⓘ next to the network in Settings → Wi-Fi), so the network
  can't recognize the phone from one visit to the next. When you leave, forget
  the network: Settings → Wi-Fi → Edit lists the ones the phone knows, and it
  otherwise joins any network with that name later, anywhere
- **AirDrop**: Settings → General → AirDrop → **Contacts Only**. *Everyone for
  10 Minutes* when you need it; it goes back by itself
- SECURITY.md section 9's habits apply as written: check the network's name
  with the staff, give its sign-in page nothing more than a room number or an
  email address, and never go past a certificate warning

### 1.5 Configuration profiles and certificates

A profile can send all the phone's traffic through someone's proxy or VPN, make
it trust a certificate that lets them read HTTPS, or put the phone under their
management. So the only one it should have is the DNS profile (1.4), unless an
employer or school gave you theirs. Never install one a website or a message
offers.

- Settings → General → VPN & Device Management lists them: remove one you
  didn't install
- Settings → General → About → Certificate Trust Settings lists the
  certificates a profile added that the phone trusts for every site: it should
  list none
- An app from outside the App Store, signed with a company's or a developer's
  certificate, skipped Apple's review, and runs only once you trust its
  developer in VPN & Device Management: treat it as you would a profile.
  `iphone/apps.py` marks one
- **Shadowrocket's HTTPS Decryption** makes a certificate of its own, for you
  to install and trust, so that a config's rewrites and scripts can see inside
  HTTPS. Keep it off, and its certificate off the phone: with it on, a
  config's scripts can read and change what goes to the sites the config
  lists, and send it elsewhere. Use the provider's subscription and rules you
  trust, not configs or modules found online. The monthly check lists the
  certificate's profile like any other

The monthly check lists every profile but the DNS one.

### 1.6 Backups

- **iCloud Backup**: Settings → your name → iCloud → iCloud Backup, on, so a
  replacement phone gets everything back
- **Advanced Data Protection**, where Apple offers it: Settings → your name →
  iCloud → Advanced Data Protection. It encrypts the backup, Photos, Notes and
  most of iCloud end to end, so a breach at Apple, or a demand made to it,
  reveals none of them. It needs a recovery contact or a recovery key: keep the
  key in KeePassXC, since Apple can't let you in without one of them
- **A backup to a Mac**, in Finder → the iPhone → General: turn on *Encrypt
  local backup*, and keep its password in KeePassXC. An unencrypted backup
  leaves out saved passwords and Health data, and leaves the rest readable on
  the Mac. On the same page, keep *Show this iPhone when on Wi-Fi* off unless
  you sync that way: with it on, a Mac the phone trusts can reach the phone
  over the network, not just the cable

The monthly check reads both settings.

### 1.7 If the phone is lost or stolen

In this order:

1. **Mark it lost or erase it**: icloud.com/find, which signs you in without
   the code the phone would have received, or Find My on a Mac. Mark As Lost
   locks it and shows a number to call; erase it once it's not coming back.
   Don't remove it from your account, even after erasing it: that turns off
   Activation Lock
2. **Suspend the SIM** with the carrier, so your texted codes and calls stop
   reaching whoever has it, and get the number moved to a new SIM
3. **Change the Apple Account password** from a Mac
4. **Sign it out**: SECURITY.md section 10, step 3, for the apps signed in on
   it, except your Apple Account's device list, as in step 1
5. **Shadowrocket's subscription URL**: reset it with the provider, since it's
   a credential itself, as Clash Verge Rev's is (SECURITY.md section 10)
6. **Authenticator codes**: for an account whose codes were only on the phone,
   sign in with its recovery codes and set the codes up again on the new phone

---

## 2. The monthly check

When the Mac's monthly update reminder comes up (MIGRATION.md section 8),
check the phone too. On the Mac, with the phone connected over USB and
locked, after unlocking it within the hour (a phone locked longer keeps its
port to charging, 1.1):

```sh
iphone/check.py
```

It lists what isn't as section 1 says, of what iOS lets a computer read:

- the iOS version, against Apple's list of releases for the model (1.3)
- a passcode, which the phone reports only while it's locked: unlocked, it
  reads as if there were none (1.1)
- the DNS over HTTPS profile, and any other profile (1.4, 1.5)
- encrypted backups to a Mac, and Wi-Fi sync (1.6)

It only reads, through the pairing Finder made when the phone first trusted
the Mac, and prints none of the phone's identifiers. It talks to the phone with
pymobiledevice3, a third-party package that uv downloads on the first run and
keeps in its cache; `uv cache clean pymobiledevice3` removes it.

```sh
iphone/apps.py
```

It lists the apps you installed, largest first, with how much of that is their
data, and marks any that didn't come from the App Store (1.5) or that iOS
offloaded. It removes nothing. The phone doesn't tell a computer when an app
was last used, but Settings → General → iPhone Storage does: delete what you no
longer use (1.3), or offload it there, which keeps its data for when you
reinstall it. Before deleting an app that holds sign-in codes, an
authenticator or a game launcher with one built in, move those accounts'
two-factor elsewhere: the codes go with it. For an app you keep, its own
clear-cache setting, where it has one, gets back most of the space its data
takes. The list stays out of the repo, which is public.

Then by hand, since the phone doesn't tell a computer:

- Settings → General → Software Update: install what's waiting, and check
  that Automatic Updates is still all on (1.3)
- Find My and Stolen Device Protection, still on (1.2)
- Settings → Wi-Fi → Edit: forget the networks you won't join again (1.4)
- AirDrop, still Contacts Only (1.4)
- Settings → your name: every device signed in to your Apple Account is yours
- Settings → Privacy & Security → Safety Check → Manage Sharing & Access: what
  people and apps can see, such as your location and photos, and which you
  meant to share
