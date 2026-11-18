import 'dart:convert';
import 'dart:io';
import 'package:yaml_edit/yaml_edit.dart';

class PackageRoot {
  const PackageRoot(this.directory, this.name);
  final String directory;
  final String? name;
}

/// The nearest directory that contains `pubspec.yaml`, at most twenty levels up.
PackageRoot? packageRoot(String file) {
  var directory = Directory(File(file).absolute.parent.path);
  for (var level = 0; level < 20; level++) {
    final spec = File(_join(directory.path, 'pubspec.yaml'));
    if (spec.existsSync()) {
      final match = RegExp(
        '''^[ \\t]*name:[ \\t]*["']?([^"'\\s#]+)''',
        multiLine: true,
      ).firstMatch(spec.readAsStringSync());
      return PackageRoot(directory.path, match?.group(1));
    }
    final parent = directory.parent;
    if (parent.path == directory.path) return null;
    directory = parent;
  }
  return null;
}

/// The library text before `::section`, or [uri] when it names the whole library.
String libraryTarget(String uri) {
  final marker = uri.indexOf('::');
  return marker < 0 ? uri : uri.substring(0, marker);
}

/// The section after `::`, or null when [uri] names the whole library.
String? librarySection(String uri) {
  final marker = uri.indexOf('::');
  if (marker < 0) return null;
  return uri.substring(marker + 2);
}

/// A section path: `graph` or `graph::weighted`.
final librarySectionPattern =
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(::[A-Za-z_][A-Za-z0-9_]*)*$');

/// `src.sum` is `src/sum.quds`. A trailing `::section` is kept after the path.
///
/// `package:flutter.material` is `package:flutter/material.dart`. The first
/// segment is the package name. Each later dot is a directory. A trailing
/// `.dart` or `.quds` is the file extension, not another directory.
String normalizeImportUri(String uri) {
  final section = librarySection(uri);
  final library = section == null ? uri : libraryTarget(uri);
  final normalized = _normalizeLibraryUri(library);
  if (section == null) return normalized;
  return '$normalized::$section';
}

String _normalizeLibraryUri(String uri) {
  final package = _packageDots(uri);
  if (package != null) return package;
  if (uri.contains(':') || uri.contains('/') || uri.contains('\\')) {
    return uri;
  }
  if (uri.endsWith('.dart')) return uri;
  final dotted = _dotPath(uri);
  if (dotted != null) return dotted;
  if (uri.endsWith('.quds')) return uri;
  return '$uri.quds';
}

String? _packageDots(String uri) {
  if (!uri.startsWith('package:')) return null;
  var rest = uri.substring('package:'.length);
  if (rest.isEmpty ||
      rest.contains('/') ||
      rest.contains('\\') ||
      !rest.contains('.')) {
    return null;
  }
  if (rest.endsWith('.dart')) {
    rest = rest.substring(0, rest.length - 5);
  } else if (rest.endsWith('.quds')) {
    rest = rest.substring(0, rest.length - 5);
  }
  if (rest.isEmpty || !rest.contains('.')) return null;
  final parts = rest.split('.');
  if (parts.length < 2 || parts.any((part) => part.isEmpty)) return null;
  return 'package:${parts.first}/${parts.skip(1).join('/')}.dart';
}

/// `src.sum` is `src/sum.quds`. A segment of only `^` climbs directories.
String? _dotPath(String uri) {
  if (!uri.contains('.') && !uri.startsWith('^')) return null;
  var body = uri;
  if (body.endsWith('.quds')) body = body.substring(0, body.length - 5);
  if (body.isEmpty || body.startsWith('.') || body.endsWith('.')) return null;
  final parts = body.split('.');
  if (parts.any((part) => part.isEmpty)) return null;
  final segments = <String>[];
  var named = false;
  for (final part in parts) {
    if (RegExp(r'^\^+$').hasMatch(part)) {
      segments.addAll(List.filled(part.length, '..'));
      continue;
    }
    if (part.contains('^')) return null;
    named = true;
    segments.add(part);
  }
  if (!named) return null;
  return '${segments.join('/')}.quds';
}

final _fileSectionCache = <String, (String, List<String>)>{};

/// Column-0 `::` headers in [path]. The scan does not parse or type-check.
List<String> fileSectionNames(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final stat = file.statSync();
  final stamp = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
  final cached = _fileSectionCache[path];
  if (cached != null && cached.$1 == stamp) return cached.$2;
  final names = sectionHeadersIn(file.readAsStringSync());
  _fileSectionCache[path] = (stamp, names);
  return names;
}

/// Column-0 `::` headers in [source], in source order.
List<String> sectionHeadersIn(String source) {
  final names = <String>[];
  final seen = <String>{};
  for (final line in source.split('\n')) {
    if (!line.startsWith('::')) continue;
    var header = line.substring(2).trim();
    final comment = header.indexOf('#');
    if (comment >= 0) header = header.substring(0, comment).trimRight();
    if (header.isEmpty || !librarySectionPattern.hasMatch(header)) continue;
    if (seen.add(header)) names.add(header);
  }
  return names;
}

/// Inclusive 0-based fold ranges for one open buffer.
///
/// A `:: path` header folds through nested `path::child` sections and stops
/// before the next header that is not a descendant. A bare `::` ends the
/// section and is not itself a fold. Indentation blocks and `# region` pairs
/// fold too: an editor that registers this provider no longer applies its
/// own indentation folds.
List<Map<String, Object>> foldingRanges(String source) {
  final lines = [
    for (final line in source.split('\n'))
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line,
  ];
  return [
    ..._sectionFolds(lines),
    ..._markerFolds(lines),
    ..._indentFolds(lines),
  ];
}

List<Map<String, Object>> _sectionFolds(List<String> lines) {
  final headers = <({int line, String path, bool fold})>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('::')) continue;
    var path = line.substring(2).trim();
    final comment = path.indexOf('#');
    if (comment >= 0) path = path.substring(0, comment).trimRight();
    headers.add((
      line: i,
      path: path,
      fold: librarySectionPattern.hasMatch(path),
    ));
  }
  final ranges = <Map<String, Object>>[];
  for (var i = 0; i < headers.length; i++) {
    final header = headers[i];
    if (!header.fold) continue;
    var end = lines.length - 1;
    for (var j = i + 1; j < headers.length; j++) {
      final other = headers[j].path;
      if (other.startsWith('${header.path}::')) continue;
      end = headers[j].line - 1;
      break;
    }
    while (end > header.line && lines[end].trim().isEmpty) end--;
    if (end <= header.line) continue;
    ranges.add({
      'startLine': header.line,
      'endLine': end,
      'kind': 'region',
      'collapsedText': header.path,
    });
  }
  return ranges;
}

List<Map<String, Object>> _markerFolds(List<String> lines) {
  final open = RegExp(r'^\s*#\s*region\b\s*(.*)$');
  final close = RegExp(r'^\s*#\s*end\s+region\b');
  final stack = <({int line, String label})>[];
  final ranges = <Map<String, Object>>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final start = open.firstMatch(line);
    if (start != null) {
      stack.add((line: i, label: start.group(1)!.trim()));
      continue;
    }
    if (close.hasMatch(line) && stack.isNotEmpty) {
      final region = stack.removeLast();
      if (i <= region.line) continue;
      ranges.add({
        'startLine': region.line,
        'endLine': i,
        'kind': 'region',
        if (region.label.isNotEmpty) 'collapsedText': region.label,
      });
    }
  }
  return ranges;
}

List<Map<String, Object>> _indentFolds(List<String> lines) {
  final stack = <({int line, int indent})>[];
  final ranges = <Map<String, Object>>[];
  var last = lines.length - 1;
  while (last > 0 && lines[last].trim().isEmpty) last--;

  void close(int indent, int end) {
    while (stack.isNotEmpty && indent <= stack.last.indent) {
      final start = stack.removeLast();
      var line = end;
      while (line > start.line && lines[line].trim().isEmpty) line--;
      if (line > start.line) {
        ranges.add({'startLine': start.line, 'endLine': line});
      }
    }
  }

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final indent = _indentWidth(lines[i]);
    close(indent, i - 1);
    stack.add((line: i, indent: indent));
  }
  close(-1, last);
  return ranges;
}

int _indentWidth(String line) {
  var indent = 0;
  for (final unit in line.codeUnits) {
    if (unit == 32) {
      indent++;
    } else if (unit == 9) {
      indent += 2;
    } else {
      break;
    }
  }
  return indent;
}

/// Absolute path of a `.quds` library named by [uri], resolved from [from].
///
/// `package:name` is `lib/name.quds`. `package:name/src/util` is
/// `lib/src/util.quds`. `generated:user_models` is
/// `lib/generated/user_models.quds` in the same package. A relative `.quds`
/// path resolves beside [from].
String? resolveLibraryPath(String from, String uri) {
  uri = libraryTarget(uri);
  if (uri.endsWith('.quds')) {
    return Uri.file(from).resolve(uri).toFilePath();
  }
  final root = packageRoot(from);
  if (root == null) return null;
  if (uri.startsWith('package:')) {
    var rest = uri.substring('package:'.length);
    if (rest.endsWith('.dart')) rest = rest.substring(0, rest.length - 5);
    if (rest.endsWith('.quds')) rest = rest.substring(0, rest.length - 5);
    if (rest.isEmpty || rest.endsWith('/')) return null;
    final slash = rest.indexOf('/');
    final relative =
        slash < 0 ? 'lib/$rest.quds' : 'lib/${rest.substring(slash + 1)}.quds';
    return _join(root.directory, relative);
  }
  if (uri.startsWith('generated:')) {
    final name = uri.substring('generated:'.length);
    if (name.isEmpty || name.contains('/') || name.contains(':')) return null;
    return _join(root.directory, 'lib/generated/$name.quds');
  }
  return null;
}

/// Dart import URI for a resolved `package:` or `generated:` library.
///
/// An unresolved `package:` URI is omitted so the emitter keeps the source
/// text. `generated:` uses the pubspec name when that file declares one.
String? dartLibraryUri(String from, String uri) {
  uri = libraryTarget(uri);
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    if (rest.isEmpty || rest.endsWith('/')) return null;
    if (rest.endsWith('.dart')) return uri;
    if (rest.endsWith('.quds'))
      return '${uri.substring(0, uri.length - 5)}.dart';
    if (rest.contains('/')) return '$uri.dart';
    return 'package:$rest/$rest.dart';
  }
  if (uri.startsWith('generated:')) {
    final name = uri.substring('generated:'.length);
    if (name.isEmpty || name.contains('/') || name.contains(':')) return null;
    final package = packageRoot(from)?.name;
    if (package == null) return 'generated/$name.dart';
    return 'package:$package/generated/$name.dart';
  }
  return null;
}

class PackageLibrary {
  const PackageLibrary(this.name, this.libDirectory);
  final String name;

  /// Absolute directory of this package's `lib` folder.
  final String libDirectory;
}

final _packageLists = <String, (String, List<PackageLibrary>)>{};

/// Packages named by the nearest `.dart_tool/package_config.json`.
List<PackageLibrary> packageLibraries(String file) {
  final root = packageRoot(file);
  if (root == null) return const [];
  final config = File(_join(root.directory, '.dart_tool/package_config.json'));
  if (!config.existsSync()) return const [];
  final stat = config.statSync();
  final stamp = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
  final cached = _packageLists[config.path];
  if (cached != null && cached.$1 == stamp) return cached.$2;
  final libraries = <PackageLibrary>[];
  try {
    final decoded = jsonDecode(config.readAsStringSync());
    if (decoded is Map && decoded['packages'] is List) {
      for (final entry in decoded['packages'] as List) {
        if (entry is! Map) continue;
        final name = entry['name'];
        final rootUri = entry['rootUri'];
        if (name is! String || name.isEmpty || rootUri is! String) continue;
        final packageUri = entry['packageUri'];
        var resolved = config.uri.resolve(rootUri);
        if (!resolved.path.endsWith('/')) {
          resolved = resolved.replace(path: '${resolved.path}/');
        }
        final lib = resolved.resolve(
            packageUri is String && packageUri.isNotEmpty
                ? packageUri
                : 'lib/');
        libraries.add(PackageLibrary(name, lib.toFilePath()));
      }
    }
  } on FormatException {
    return const [];
  }
  libraries.sort((a, b) => a.name.compareTo(b.name));
  _packageLists[config.path] = (stamp, libraries);
  return libraries;
}

/// The file named by a `package:` URI that already ends in `.dart`.
File? packageDartFile(String from, String uri) {
  if (!uri.startsWith('package:') || !uri.endsWith('.dart')) return null;
  final rest = uri.substring('package:'.length);
  final slash = rest.indexOf('/');
  if (slash <= 0 || slash == rest.length - 1) return null;
  final name = rest.substring(0, slash);
  final relative = rest.substring(slash + 1);
  if (relative.contains('\\') || relative.split('/').contains('..')) {
    return null;
  }
  for (final library in packageLibraries(from)) {
    if (library.name != name) continue;
    var base = Directory(library.libDirectory).uri;
    if (!base.path.endsWith('/')) {
      base = base.replace(path: '${base.path}/');
    }
    final file = File(base.resolve(relative).toFilePath());
    if (!file.existsSync()) return null;
    return file;
  }
  return null;
}

/// True when the package that contains [file] depends on `package:meta`.
bool packageDependsOnMeta(String file) {
  final root = packageRoot(file);
  if (root == null) return false;
  final spec = File(_join(root.directory, 'pubspec.yaml'));
  if (!spec.existsSync()) return false;
  return RegExp(r'^[ \t]*meta[ \t]*:', multiLine: true)
      .hasMatch(spec.readAsStringSync());
}

String _join(String root, String relative) {
  final separator = Platform.pathSeparator;
  final tail = relative.replaceAll('/', separator);
  if (root.endsWith(separator)) return '$root$tail';
  return '$root$separator$tail';
}

/// A generated Quds library mirrors its source directory under the output root.
/// Keep internal compiler imports relative too, rather than pointing at a Dart
/// file beside the original source which the CLI deliberately never writes.
String qudsBackendLibraryUri(String from, String home) {
  final source = File(from).absolute.parent.uri.normalizePath();
  final target = File(home.replaceFirst(RegExp(r'\.quds$'), '.dart'))
      .absolute
      .uri
      .normalizePath();
  final left = source.pathSegments.where((s) => s.isNotEmpty).toList();
  final right = target.pathSegments.where((s) => s.isNotEmpty).toList();
  var shared = 0;
  while (shared < left.length &&
      shared < right.length &&
      left[shared] == right[shared]) {
    shared++;
  }
  return [...List.filled(left.length - shared, '..'), ...right.skip(shared)]
      .map((s) => s == '..' ? s : Uri.encodeComponent(s))
      .join('/');
}

/// Embedded Dart libraries supplied by an SDK package (for example dart:ui).
File? embeddedDartFile(String from, String uri) {
  if (!uri.startsWith('dart:')) return null;
  for (final library in packageLibraries(from)) {
    final configuration = File.fromUri(
        Directory(library.libDirectory).absolute.uri.resolve('_embedder.yaml'));
    if (!configuration.existsSync()) continue;
    final expression = RegExp(
        r"""["']""" + RegExp.escape(uri) + r"""["']\s*:\s*["']([^"']+)["']""");
    final match = expression.firstMatch(configuration.readAsStringSync());
    if (match == null) continue;
    final file = File.fromUri(configuration.uri.resolve(match.group(1)!));
    if (file.existsSync()) return file;
  }
  return null;
}

/// SDK dependency detection shared by compiler, CLI and editor entry points.
bool packageUsesFlutter(String file) {
  final root = packageRoot(file);
  if (root == null) return false;
  final spec = File('${root.directory}/pubspec.yaml');
  try {
    final values = YamlEditor(spec.readAsStringSync()).parseAt([]).value;
    if (values is! Map) return false;
    for (final section in [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides'
    ]) {
      final dependencies = values[section];
      if (dependencies is Map &&
          dependencies.values
              .any((value) => value is Map && value['sdk'] == 'flutter'))
        return true;
    }
  } catch (_) {/* Project tools report malformed YAML separately. */}
  return false;
}
