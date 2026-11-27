"""Synchronize the embedded math source. Run from the repository root."""
from pathlib import Path

path = Path('lib/src/sdk_sources.dart')
sdk = path.read_text()
marker = "const mathSdkSource = '''"
start = sdk.index(marker) + len(marker)
end = sdk.index("\n''';", start)
source = Path('lib/sdk/math.quds').read_text()
escaped = source.replace('\\', '\\\\').replace('$', '\\$').replace("'''", "\\'\\'\\'")
path.write_text(sdk[:start] + escaped.rstrip('\n') + sdk[end:])
