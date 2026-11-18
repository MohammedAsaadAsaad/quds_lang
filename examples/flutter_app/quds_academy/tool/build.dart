import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/sdk.dart';

void main() {
  final root = Directory.current;
  final lib = Directory('${root.path}/lib');
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.quds'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final relative = file.path.substring(lib.path.length + 1);
    final output =
        File('${lib.path}/quds_gen/${relative.replaceAll('.quds', '.dart')}');
    var compilation = compile(file.readAsStringSync(), file: file.path);
    final depth = relative.split(Platform.pathSeparator).length - 1;
    compilation = relocateGeneratedLibraries(compilation, '../' * depth);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(compilation.dart);
    if (compilation.sourceMap != null) {
      File('${output.path}.map').writeAsStringSync(compilation.sourceMap!);
    }
    writeSdkBundles(output.parent.path, compilation);
    stdout.writeln('Quds → $relative');
  }
  File('${lib.path}/main.dart')
      .writeAsStringSync('// Generated Flutter bootstrap; edit lib/main.quds.\n'
          "import 'quds_gen/main.dart' as academy;\n"
          'void main() => academy.main();\n');
}
