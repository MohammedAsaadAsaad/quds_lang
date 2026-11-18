#!/usr/bin/env python3
"""Run the app's actual Quds/SQLite/content suites without a Flutter engine."""
from pathlib import Path
import shutil
import subprocess
import tempfile

app = Path(__file__).resolve().parents[1]
compiler = app.parents[2] / 'bin/quds.dart'
with tempfile.TemporaryDirectory(prefix='quds-academy-core-') as directory:
    root = Path(directory)
    (root / 'lib/src').mkdir(parents=True)
    (root / 'test').mkdir()
    (root / 'pubspec.yaml').write_text('name: academy_core_check\nenvironment:\n  sdk: ">=3.13.0 <4.0.0"\ndependencies:\n  sqlite_plus: 0.1.14\n')
    for source in (app / 'lib/src').glob('*.quds'):
        shutil.copy2(source, root / 'lib/src' / source.name)
    shutil.copy2(app / 'test/core_test.quds', root / 'test/core_test.quds')
    subprocess.run(['dart', 'pub', 'get'], cwd=root, check=True)
    subprocess.run(['dart', str(compiler), 'test', str(root / 'test/core_test.quds')], cwd=root, check=True)
