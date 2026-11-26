#!/usr/bin/env python3
"""Generate local-only receiver credentials; never overwrites an existing config."""
from pathlib import Path
import argparse
import ipaddress
import os
import secrets

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host', help='Kindle private IPv4 address; also write local Shortcut URLs')
args = parser.parse_args()
if args.host:
    address = ipaddress.ip_address(args.host)
    if address.version != 4 or not address.is_private or address.is_loopback:
        parser.error('Use the Kindle private-network IPv4 address')
    host = str(address)
folder = ROOT/'extension/kindle-watch-keys'
config = folder/'config.lua'
if config.exists():
    parser.error('config.lua already exists; keep it when updating to preserve your Shortcut token')
urls = folder/'shortcut-urls.txt'
if args.host and urls.exists():
    parser.error('shortcut-urls.txt already exists; move it aside before generating new credentials')
token = secrets.token_hex(16)
content = ('return { port = 8888, duration = 900, reading_duration = 7200, token = "'
           + token + '" }\n')
with config.open('x') as output:
    os.chmod(config, 0o600)
    output.write(content)
if args.host:
    with urls.open('x') as output:
        os.chmod(urls, 0o600)
        output.write('Next page:\nhttp://' + host + ':8888/next?token=' + token + '\n\n'
                     'Previous page:\nhttp://' + host + ':8888/prev?token=' + token + '\n')
print('Created local config.lua (excluded from Git).')
if args.host:
    print('Shortcut URLs are in local shortcut-urls.txt (also excluded from Git).')
