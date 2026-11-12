import 'dart:io';

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

/// Absolute path of a `.quds` library named by [uri], resolved from [from].
///
/// `package:name` is `lib/name.quds`. `package:name/src/util` is
/// `lib/src/util.quds`. `generated:user_models` is
/// `lib/generated/user_models.quds` in the same package. A relative `.quds`
/// path resolves beside [from].
String? resolveLibraryPath(String from, String uri) {
  if (uri.endsWith('.quds')) {
    return Uri.file(from).resolve(uri).toFilePath();
  }
  final root = packageRoot(from);
  if (root == null) return null;
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
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
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    if (rest.isEmpty || rest.endsWith('/')) return null;
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
