/// Pure-Dart library URI and section helpers (no `dart:io` dependency).
///
/// Shared by the compiler, embedded interpreter, and embedded editor engine so
/// they work across Dart VM, Flutter Desktop/Mobile, and Web.
library;

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

/// A `quds:` import. [section] is null for the whole library.
class SdkImport {
  const SdkImport(this.library, this.section);
  final String library;

  /// `graph`, or `graph::weighted`. Null imports every public name.
  final String? section;
}

final _sdkIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// `quds:math` and `quds:math::graph::weighted`. Null when the URI is not a
/// library name followed by optional `::` sections.
SdkImport? sdkImport(String uri) {
  if (!uri.startsWith('quds:')) return null;
  final body = uri.substring('quds:'.length);
  if (body.isEmpty) return null;
  final parts = body.split('::');
  for (final part in parts) {
    if (!_sdkIdentifier.hasMatch(part)) return null;
  }
  if (parts.length == 1) return SdkImport(parts.first, null);
  return SdkImport(parts.first, parts.sublist(1).join('::'));
}

/// `quds:core` -> `core`. `quds:math::graph` -> `math`.
String? sdkLibraryName(String uri) => sdkImport(uri)?.library;
