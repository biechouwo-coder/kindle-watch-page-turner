#!/usr/bin/env python3
"""Call the receiver without printing its token or retrying page actions."""
from pathlib import Path
import argparse
import ipaddress
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('host', help='Kindle private IPv4 address')
parser.add_argument('action', choices=['health','probe','status','arm-once','arm-five','next','prev','stop'])
parser.add_argument('--interface', help='Optional network interface, e.g. en0; does not change system routing')
parser.add_argument('--config', type=Path, default=ROOT/'extension/kindle-watch-keys/config.lua')
args = parser.parse_args()
host = ipaddress.ip_address(args.host)
if host.version != 4 or not host.is_private or host.is_loopback:
    parser.error('Use the Kindle private-network IPv4 address')
path = '/' + args.action
if args.action != 'health':
    try:
        match = re.search(r'token\s*=\s*"([0-9a-f]{32})"', args.config.read_text())
    except OSError:
        parser.error('Local config.lua not found; generate or provide your device config')
    if not match:
        parser.error('The config must contain a 32-character hexadecimal token')
    path += '?token=' + match.group(1)
command = ['curl', '--noproxy', '*', '--connect-timeout', '3', '--max-time', '15',
           '--fail-with-body', '-sS', '-i', '--config', '-']
if args.interface:
    command.extend(['--interface', args.interface])
try:
    result = subprocess.run(command, input='url = "http://' + str(host) + ':8888' + path + '"\n', text=True)
except FileNotFoundError:
    parser.error('curl is required; --fail-with-body needs curl 7.76 or later')
raise SystemExit(result.returncode)
