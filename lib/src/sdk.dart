import 'dart:io';

import 'library_uri.dart';
import 'sdk_sources.dart';

export 'library_uri.dart' show SdkImport, sdkImport, sdkLibraryName;
export 'sdk_sources.dart';

List<String>? _sdkLibraryNames;
String? _sdkLibraryStamp;

/// SDK library names, from memory. The `lib/sdk` directory is read again only
/// when that directory itself changes.
List<String> sdkLibraryNames() {
  String? stamp;
  Directory? directory;
  for (final root in _packageRoots()) {
    final candidate = Directory(
        '$root${Platform.pathSeparator}lib${Platform.pathSeparator}sdk');
    if (!candidate.existsSync()) continue;
    directory = candidate;
    final stat = candidate.statSync();
    stamp = '${candidate.path}:${stat.modified.microsecondsSinceEpoch}';
    break;
  }
  final key = stamp ?? 'embedded';
  final cached = _sdkLibraryNames;
  if (cached != null && _sdkLibraryStamp == key) return cached;
  final names = <String>{...embeddedSdk.keys};
  if (directory != null) {
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final base = entity.path.split(Platform.pathSeparator).last;
      if (!base.endsWith('.quds')) continue;
      final stem = base.substring(0, base.length - 5);
      if (sdkLibraryName('quds:$stem') == null) continue;
      names.add(stem);
    }
  }
  final sorted = names.toList()..sort();
  _sdkLibraryNames = sorted;
  _sdkLibraryStamp = key;
  return sorted;
}

final _sdkSectionCache = <String, (int, int, List<String>)>{};

/// Section paths declared by column-0 `::` headers in [library].
///
/// The scan reads the source text only. It does not parse or type-check.
List<String> sdkSectionNames(String library) {
  if (sdkLibraryName('quds:$library') == null) return const [];
  final source = readSdk(library);
  if (source == null) return const [];
  final cached = _sdkSectionCache[library];
  if (cached != null &&
      cached.$1 == source.length &&
      cached.$2 == source.hashCode) {
    return cached.$3;
  }
  final names = sectionHeadersIn(source);
  _sdkSectionCache[library] = (source.length, source.hashCode, names);
  return names;
}

/// Generated Dart file written beside the caller's output.
String sdkDartFileName(String name) => 'quds_$name.dart';

/// Absolute path of `lib/sdk/<name>.quds` inside this compiler package.
String? sdkPath(String name) {
  if (sdkLibraryName('quds:$name') == null) return null;
  for (final root in _packageRoots()) {
    final file = File(
        '$root${Platform.pathSeparator}lib${Platform.pathSeparator}sdk${Platform.pathSeparator}$name.quds');
    if (file.existsSync()) return file.path;
  }
  return null;
}

/// The on-disk library when this package is available, otherwise the embedded copy.
String? readSdk(String name) {
  if (sdkLibraryName('quds:$name') == null) return null;
  final path = sdkPath(name);
  if (path != null) return File(path).readAsStringSync();
  return embeddedSdk[name];
}

/// Bytes mixed into the incremental cache so an SDK edit rebuilds outputs.
String sdkDigestMaterial() {
  final names = embeddedSdk.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final name in names) {
    buffer.writeln(name);
    buffer.write(readSdk(name) ?? '');
    buffer.writeCharCode(0);
  }
  return buffer.toString();
}

List<String> _packageRoots() {
  final roots = <String>[];
  final seen = <String>{};
  void walk(String start) {
    var directory = Directory(start);
    for (var level = 0; level < 20; level++) {
      if (!seen.add(directory.path)) return;
      final spec =
          File('${directory.path}${Platform.pathSeparator}pubspec.yaml');
      if (spec.existsSync()) {
        final match = RegExp(
          '''^[ \\t]*name:[ \\t]*["']?([^"'\\s#]+)''',
          multiLine: true,
        ).firstMatch(spec.readAsStringSync());
        if (match?.group(1) == 'quds' || match?.group(1) == 'quds_lang') {
          roots.add(directory.path);
        }
      }
      final parent = directory.parent;
      if (parent.path == directory.path) return;
      directory = parent;
    }
  }

  walk(File(Platform.resolvedExecutable).parent.path);
  try {
    final script = Platform.script.toFilePath();
    if (script.isNotEmpty) walk(File(script).parent.path);
  } catch (_) {}
  walk(Directory.current.path);
  return roots;
}
