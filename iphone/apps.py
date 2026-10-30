#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pymobiledevice3~=11.48"]
# ///
#
# Lists the apps you installed on the iPhone connected to this Mac, largest
# first, with the space their data takes, and marks any that didn't come from
# the App Store or that iOS offloaded (IPHONE.md section 2). It only reads, as
# iphone/check.py does.
#
import asyncio
import sys
import unicodedata

from pymobiledevice3.exceptions import (ConnectionFailedError, NoDeviceConnectedError, PairingError,
                                        NotPairedError)
from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.installation_proxy import InstallationProxyService

# The App Store's signature, which TestFlight's builds carry too
APP_STORE = 'Apple iPhone OS Application Signing'


def size(n):
    return f'{n / 1e9:.1f} GB' if n >= 1e9 else f'{n / 1e6:.0f} MB'


def clean(s):
    """Without the invisible characters some names carry, such as a direction mark"""
    return ''.join(c for c in s if unicodedata.category(c) != 'Cf')


def pad(s, width):
    """s cut or padded to width columns, Chinese and Japanese characters taking two"""
    out, used = '', 0
    for c in s:
        w = 2 if unicodedata.east_asian_width(c) in 'WF' else 1
        if used + w > width:
            break
        out, used = out + c, used + w
    return out + ' ' * (width - used)


async def main():
    try:
        lockdown = await create_using_usbmux(autopair=False)
    except (NoDeviceConnectedError, ConnectionFailedError):
        sys.exit('No iPhone connected: connect it over USB and unlock it')
    except (NotPairedError, PairingError):
        sys.exit("The iPhone hasn't trusted this Mac: unlock it, tap Trust, and run this again")
    try:
        async with InstallationProxyService(lockdown) as ip:
            apps = await ip.get_apps(application_type='User', calculate_sizes=True)
    finally:
        await lockdown.close()

    rows = []
    for bundle_id, app in apps.items():
        data = app.get('DynamicDiskUsage') or 0
        if app.get('IsDemotedApp'):
            note = 'offloaded'
        elif (app.get('Entitlements') or {}).get('beta-reports-active'):
            note = 'TestFlight'
        elif app.get('SignerIdentity') != APP_STORE:
            note = f'not from the App Store: signed by {app.get("SignerIdentity")}'
        else:
            note = ''
        name = clean(app.get('CFBundleDisplayName') or app.get('CFBundleName') or bundle_id)
        rows.append(((app.get('StaticDiskUsage') or 0) + data, data, name,
                     app.get('CFBundleShortVersionString', ''), bundle_id, note))
    rows.sort(key=lambda r: r[0], reverse=True)

    print(f'{len(rows)} apps, {size(sum(r[0] for r in rows))} with their data')
    print(f'{"Size":>7}  {"Data":>7}  {pad("Name", 28)}  {pad("Version", 14)}  Bundle ID')
    for total, data, name, ver, bundle_id, note in rows:
        print(f'{size(total):>7}  {size(data):>7}  {pad(name, 28)}  {pad(ver, 14)}  {bundle_id}' +
              (f'  ({note})' if note else ''))
    print('When each was last used: Settings → General → iPhone Storage')


asyncio.run(main())
