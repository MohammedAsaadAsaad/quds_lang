"""Synchronize embedded SDK sources; optional arguments select library names."""
from pathlib import Path
import sys

names = sys.argv[1:] or ['core', 'ext', 'math']
if any(name not in {'core', 'ext', 'math'} for name in names):
    raise SystemExit('Expected core, ext, or math')
path = Path('lib/src/sdk.dart')
sdk = path.read_text()
for name in names:
    marker = f"const {name}SdkSource = '''"
    start = sdk.index(marker) + len(marker)
    end = sdk.index("\n''';", start)
    source = Path(f'lib/sdk/{name}.quds').read_text()
    escaped = source.replace('\\', '\\\\').replace('$', '\\$').replace("'''", "\\'\\'\\'")
    sdk = sdk[:start] + escaped.rstrip('\n') + sdk[end:]
path.write_text(sdk)
