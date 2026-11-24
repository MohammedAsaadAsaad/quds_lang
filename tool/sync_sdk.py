"""Synchronize embedded SDK sources; optional arguments select library names."""
from pathlib import Path
import sys

supported = ('core', 'ext', 'math', 'text', 'collection', 'async', 'json')
names = sys.argv[1:] or ['core', 'ext', 'math']
if any(name not in supported for name in names):
    raise SystemExit(f'Expected one of: {", ".join(supported)}')
path = Path('lib/src/sdk.dart')
sdk = path.read_text()
for name in names:
    raw_marker = f"const {name}SdkSource = r'''"
    std_marker = f"const {name}SdkSource = '''"
    if raw_marker in sdk:
        marker = raw_marker
        is_raw = True
    elif std_marker in sdk:
        marker = std_marker
        is_raw = False
    else:
        raise SystemExit(f'Marker for {name}SdkSource not found in lib/src/sdk.dart')
    start = sdk.index(marker) + len(marker)
    end = sdk.index("\n''';", start)
    source = Path(f'lib/sdk/{name}.quds').read_text()
    if is_raw:
        if "'''" in source:
            raise SystemExit(f'Triple single quote found in raw SDK {name}.quds')
        body = source.rstrip('\n')
    else:
        body = source.replace('\\', '\\\\').replace('$', '\\$').replace("'''", "\\'\\'\\'").rstrip('\n')
    sdk = sdk[:start] + body + sdk[end:]
path.write_text(sdk)
