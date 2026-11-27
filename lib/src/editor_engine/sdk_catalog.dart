/// Lazy, pure-Dart symbol & section index of the embedded `quds:*` SDK
/// libraries for instant editor autocomplete, hover docs, and signature help.
///
/// Zero `dart:io` imports.
library;

import '../library_uri.dart';
import '../sdk_sources.dart';

/// Indexed public declaration extracted from an embedded `quds:*` SDK source.
class QudsSdkSymbol {
  const QudsSdkSymbol({
    required this.name,
    required this.library,
    required this.kind, // 'function' | 'class' | 'constant'
    required this.signature,
    this.section = '',
    this.documentation,
  });

  final String name;
  final String library;
  final String kind;
  final String signature;
  final String section;
  final String? documentation;
}

/// Lightweight cached index over [embeddedSdk].
class QudsSdkCatalog {
  static final Map<String, List<QudsSdkSymbol>> _symbolsByLib = {};
  static final Map<String, List<String>> _sectionsByLib = {};

  static List<String> get libraryNames => const [
        'core',
        'ext',
        'math',
        'text',
        'collection',
        'async',
        'json',
        'viz',
        'data',
      ];

  /// Returns all `:: section` headers declared in [library] (e.g. `math`).
  static List<String> sectionsOf(String library) {
    final cached = _sectionsByLib[library];
    if (cached != null) return cached;
    final source = embeddedSdk[library];
    if (source == null) return const [];
    final sections = sectionHeadersIn(source);
    _sectionsByLib[library] = sections;
    return sections;
  }

  /// Returns all indexed public declarations of [library], optionally filtered
  /// to a `:: section` (including nested child sections).
  static List<QudsSdkSymbol> symbolsOf(String library, {String? section}) {
    final all =
        _symbolsByLib.putIfAbsent(library, () => _indexLibrary(library));
    if (section == null || section.isEmpty) return all;
    return [
      for (final s in all)
        if (s.section == section || s.section.startsWith('$section::')) s,
    ];
  }

  static final _fnHeader = RegExp(
      r'^([A-Za-z][A-Za-z0-9_]*)(?:<[^>]*>)?\(([^)]*)\)(?:\s*async)?(?:\s*->\s*([^:=]+))?[:=]');
  static final _classHeader = RegExp(
      r'^(?:(?:value|sealed|abstract|base|final|interface|mixin|singleton)\s+)*(class|enum|interface|type)\s+([A-Za-z][A-Za-z0-9_]*)');
  static final _constHeader = RegExp(r'^const\s+([A-Za-z][A-Za-z0-9_]*)');

  static List<QudsSdkSymbol> _indexLibrary(String library) {
    final source = embeddedSdk[library];
    if (source == null) return const [];
    final lines = source.split('\n');
    final out = <QudsSdkSymbol>[];
    final seen = <String>{};
    var currentSection = '';
    final docLines = <String>[];

    for (final raw in lines) {
      final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      if (line.startsWith('::')) {
        final header = line.substring(2).split('#').first.trim();
        currentSection = librarySectionPattern.hasMatch(header) ? header : '';
        docLines.clear();
        continue;
      }
      if (line.startsWith('#') || line.startsWith('///')) {
        final text = line.startsWith('///')
            ? line.substring(3).trim()
            : line.substring(1).trim();
        docLines.add(text);
        continue;
      }
      if (line.trim().isEmpty) {
        docLines.clear();
        continue;
      }
      if (line.startsWith(' ') || line.startsWith('\t')) {
        docLines.clear();
        continue;
      }

      final doc = docLines.isEmpty ? null : docLines.join('\n');
      docLines.clear();

      if (line.startsWith('internal ') ||
          line.startsWith('use ') ||
          line.startsWith('export ') ||
          line.startsWith('extend ')) {
        continue;
      }

      final cm = _classHeader.firstMatch(line);
      if (cm != null) {
        final kindWord = cm.group(1)!;
        final name = cm.group(2)!;
        if (!name.startsWith('_') && seen.add('c:$name')) {
          out.add(QudsSdkSymbol(
            name: name,
            library: library,
            kind: 'class',
            signature: '$kindWord $name',
            section: currentSection,
            documentation: doc,
          ));
        }
        continue;
      }

      final km = _constHeader.firstMatch(line);
      if (km != null) {
        final name = km.group(1)!;
        if (!name.startsWith('_') && seen.add('k:$name')) {
          out.add(QudsSdkSymbol(
            name: name,
            library: library,
            kind: 'constant',
            signature: line.trim(),
            section: currentSection,
            documentation: doc,
          ));
        }
        continue;
      }

      final fm = _fnHeader.firstMatch(line);
      if (fm != null) {
        final name = fm.group(1)!;
        if (!name.startsWith('_') &&
            name != 'if' &&
            name != 'for' &&
            name != 'while' &&
            seen.add('f:$name:${fm.group(2)}')) {
          final params = fm.group(2)!.trim();
          final ret = fm.group(3)?.trim();
          final sig = ret != null && ret.isNotEmpty
              ? '$name($params) -> $ret'
              : '$name($params)';
          out.add(QudsSdkSymbol(
            name: name,
            library: library,
            kind: 'function',
            signature: sig,
            section: currentSection,
            documentation: doc,
          ));
        }
      }
    }

    // Also include re-exported dart:math essentials when indexing `math`.
    if (library == 'math') {
      for (final entry in const [
        (
          'pi',
          'constant',
          'const double pi = 3.1415926535897932',
          'Ratio of a circle circumference to its diameter.'
        ),
        (
          'e',
          'constant',
          'const double e = 2.718281828459045',
          'Base of the natural logarithm.'
        ),
        (
          'sin',
          'function',
          'sin(radians: num) -> double',
          'Sine of an angle in radians.'
        ),
        (
          'cos',
          'function',
          'cos(radians: num) -> double',
          'Cosine of an angle in radians.'
        ),
        (
          'tan',
          'function',
          'tan(radians: num) -> double',
          'Tangent of an angle in radians.'
        ),
        ('sqrt', 'function', 'sqrt(x: num) -> double', 'Square root of x.'),
        (
          'exp',
          'function',
          'exp(x: num) -> double',
          'Natural exponential e^x.'
        ),
        (
          'log',
          'function',
          'log(x: num) -> double',
          'Natural logarithm ln(x).'
        ),
        (
          'pow',
          'function',
          'pow(x: num, exponent: num) -> num',
          'Raises x to the power of exponent.'
        ),
        (
          'atan2',
          'function',
          'atan2(a: num, b: num) -> double',
          'Four-quadrant arctangent.'
        ),
      ]) {
        if (seen.add('m:${entry.$1}')) {
          out.add(QudsSdkSymbol(
            name: entry.$1,
            library: 'math',
            kind: entry.$2,
            signature: entry.$3,
            documentation: entry.$4,
          ));
        }
      }
    }

    return out;
  }
}
