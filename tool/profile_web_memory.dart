import 'dart:io';
import 'package:quds_lang/quds_lang.dart';

Future<void> main() async {
  final directory = Directory.systemTemp.createTempSync('quds-web-heap-');
  try {
    final input = File('bench/memory_workload.quds');
    final compiled = compile(input.readAsStringSync(), file: input.path);
    writeSdkBundles(directory.path, compiled);
    final file = File('${directory.path}/program.dart')
      ..writeAsStringSync(compiled.dart);
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', file.path, '-o', js]);
    if (build.exitCode != 0)
      throw StateError('${build.stdout}\n${build.stderr}');
    final run = await Process.run(
        'node', ['--expose-gc', 'tool/profile_web_memory.cjs', js]);
    stdout.write(run.stdout);
    stderr.write(run.stderr);
    exitCode = run.exitCode;
  } finally {
    directory.deleteSync(recursive: true);
  }
}
