#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pymobiledevice3~=11.48"]
# ///
#
# Reads what the iPhone connected to this Mac lets a computer read of IPHONE.md
# section 1, and lists what isn't as it says (section 2). It only reads, through
# the pairing Finder made when the iPhone trusted this Mac, and prints none of
# the phone's identifiers: its serial number, UDID, IMEI or phone number.
#
import asyncio
import json
import subprocess
import sys

from pymobiledevice3.exceptions import (ConnectionFailedError, MissingValueError,
                                        NoDeviceConnectedError, PairingError, NotPairedError)
from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.mobile_config import MobileConfigService

# The profile mac/dns-over-https.sh builds
DNS_PROFILE = 'local.dns-over-https'


def version(s):
    return tuple(int(n) for n in s.split('.'))


def releases(product_type):
    """The iOS versions Apple offers this model now, newest first, or None"""
    # macOS's curl trusts Apple's root certificate, which this server's chain
    # ends in and Python's certificate bundles leave out
    try:
        out = subprocess.run(['/usr/bin/curl', '-fsS', '--max-time', '20', 'https://gdmf.apple.com/v2/pmv'],
                             capture_output=True, check=True, text=True).stdout
        sets = json.loads(out)['PublicAssetSets']['iOS']
    except (OSError, subprocess.CalledProcessError, ValueError, KeyError):
        return None
    return sorted({a['ProductVersion'] for a in sets if product_type in a.get('SupportedDevices', [])},
                  key=version, reverse=True)


async def main():
    try:
        lockdown = await create_using_usbmux(autopair=False)
    except (NoDeviceConnectedError, ConnectionFailedError):
        sys.exit('No iPhone connected: connect it over USB and unlock it')
    except (NotPairedError, PairingError):
        sys.exit("The iPhone hasn't trusted this Mac: unlock it, tap Trust, and run this again")

    async def get(key, domain=None):
        try:
            return await lockdown.get_value(domain, key)
        except MissingValueError:
            return None

    issues, notes = [], []
    try:
        product, ios = await get('ProductType'), await get('ProductVersion')
        # True only while the phone is locked with a passcode: unlocked, it
        # reads as if there were none
        if not await get('PasswordProtected'):
            issues.append('the phone is unlocked, or has no passcode: lock it and run this again, and if this is '
                          'still here, turn one on in Settings → Face ID & Passcode (section 1.1)')
        if not await get('WillEncrypt', 'com.apple.mobile.backup'):
            issues.append("backups to a Mac aren't encrypted: Finder → the iPhone → Encrypt local backup (section 1.6)")
        # Set only once Finder's Show this iPhone when on Wi-Fi has been on
        if await get('EnableWifiConnections', 'com.apple.mobile.wireless_lockdown'):
            issues.append('a Mac can reach the iPhone over Wi-Fi: turn off Show this iPhone when on Wi-Fi in Finder (section 1.6)')
        async with MobileConfigService(lockdown) as mc:
            profiles = (await mc.get_profile_list()).get('ProfileMetadata', {})
    finally:
        await lockdown.close()

    if DNS_PROFILE not in profiles:
        issues.append('no DNS over HTTPS profile: mac/dns-over-https.sh --iphone (section 1.4)')
    for ident, meta in profiles.items():
        if ident != DNS_PROFILE:
            issues.append(f'a profile you may not know, {meta.get("PayloadDisplayName")} ({ident}) from '
                          f'{meta.get("PayloadOrganization", "no organization")}: remove it in Settings → General → '
                          'VPN & Device Management unless you installed it (section 1.5)')

    offered = releases(product)
    if not offered:
        issues.append("Apple's list of iOS releases didn't load: compare with Settings → General → Software Update (section 1.3)")
    else:
        newest = offered[0]
        same = next((v for v in offered if version(v)[0] == version(ios)[0]), None)
        if same is None:
            issues.append(f'iOS {ios} no longer gets security fixes: update to {newest} (section 1.3)')
        elif version(ios) < version(same):
            issues.append(f'iOS {ios} is behind: update to {same}' + (f', or {newest}' if same != newest else '') +
                          ' (section 1.3)')
        elif same != newest:
            notes.append(f'iOS {newest} is out; {ios} still gets security fixes, but not all of them (section 1.3)')

    print(f'{product}, iOS {ios}')
    for line in issues:
        print(f'- {line}')
    for line in notes:
        print(f'  {line}')
    if not issues:
        print('What a computer can read is as IPHONE.md section 1 says')
    print("And by hand: IPHONE.md section 2's list")


asyncio.run(main())
