"""Linux AOT peak RSS for the fixed Quds workload; no third-party modules."""
from pathlib import Path
import json
import os
import shutil
import statistics
import subprocess
import sys
import tempfile

if sys.platform != 'linux' or not hasattr(os, 'wait4'):
    raise SystemExit('This profiler uses Linux wait4 peak RSS in KiB')
root = Path(__file__).resolve().parent.parent
dart = shutil.which('dart')
if dart is None:
    raise SystemExit('dart must be on PATH')
expected = '2181009417.0\n99990000\n'
with tempfile.TemporaryDirectory(prefix='quds-rss-') as temporary:
    directory = Path(temporary)
    source = directory / 'workload.quds'
    source.write_text((root / 'bench/language_workloads.quds').read_text())
    subprocess.run([dart, 'run', 'bin/quds.dart', 'build', str(source)],
                   cwd=root, check=True, capture_output=True, text=True)
    generated = directory / '.dart_tool/quds/out/workload.dart'
    binary = directory / 'workload'
    packages = root / '.dart_tool/package_config.json'
    subprocess.run([dart, 'compile', 'exe', f'--packages={packages}',
                    str(generated), '-o', str(binary)],
                   cwd=root, check=True, capture_output=True, text=True)
    peaks = []
    for index in range(6):
        process = subprocess.Popen([str(binary)], stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        output = process.stdout.read()
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        if process.returncode != 0 or output != expected:
            raise RuntimeError(f'Workload failed/checksum differs: {output}')
        if index:
            peaks.append(usage.ru_maxrss)
    print(json.dumps({
        'schema': 1, 'metric': 'Linux wait4.ru_maxrss for each child lifetime including fork/exec',
        'unit': 'KiB', 'warmup': 1, 'repeat': 5,
        'samples': peaks, 'median': statistics.median(peaks),
        'min': min(peaks), 'max': max(peaks),
        'dart': subprocess.run([dart, '--version'], check=True,
                              capture_output=True, text=True).stdout.strip(),
        'os': sys.platform, 'checksum': expected,
        'limit': 'Includes launch/pre-exec high-water mark; may have a launcher RSS floor. Not allocations or isolated Dart heap.',
    }, indent=2))
