"""Synchronize embedded SDK sources in lib/src/sdk.dart from lib/sdk/*.quds.

Usage:
  python3 tool/sync_sdk.py [--check] [core ext math text collection async json]
"""
from pathlib import Path
import re
import sys

supported = ('core', 'ext', 'math', 'text', 'collection', 'async', 'json')
args = sys.argv[1:]
check_only = False
if '--check' in args:
    check_only = True
    args = [a for a in args if a != '--check']

names = args or list(supported)
if any(name not in supported for name in names):
    raise SystemExit(f'Expected one of: {", ".join(supported)}')

path = Path('lib/src/sdk.dart')
original_sdk = path.read_text()
sdk = original_sdk
out_of_sync = []

for name in names:
    pattern = re.compile(rf"const {name}SdkSource =\s*(r?)'''")
    match = pattern.search(sdk)
    if match is None:
        raise SystemExit(f'Marker for {name}SdkSource not found in lib/src/sdk.dart')
    is_raw = match.group(1) == 'r'
    start = match.end()
    end = sdk.index("\n''';", start)
    source = Path(f'lib/sdk/{name}.quds').read_text()
    if is_raw:
        if "'''" in source:
            raise SystemExit(f'Triple single quote found in raw SDK {name}.quds')
        body = source.rstrip('\n')
    else:
        body = (
            source.replace('\\', '\\\\')
            .replace('$', '\\$')
            .replace("'''", "\\'\\'\\'")
            .rstrip('\n')
        )
    if sdk[start:end] != body:
        out_of_sync.append(name)
        sdk = sdk[:start] + body + sdk[end:]

if check_only:
    if out_of_sync:
        raise SystemExit(f'SDK out of sync in lib/src/sdk.dart: {", ".join(out_of_sync)}')
    print(f'SDK synced: {", ".join(names)}')
elif sdk != original_sdk:
    path.write_text(sdk)
    print(f'Synced SDK in lib/src/sdk.dart: {", ".join(out_of_sync)}')
else:
    print(f'SDK already up to date: {", ".join(names)}')
