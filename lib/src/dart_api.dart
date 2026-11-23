import 'type_syntax.dart';
import 'libraries.dart';

import 'dart:io';

/// A public name read from a Dart SDK library source.
class DartTop {
  const DartTop({
    required this.name,
    required this.type,
    this.parameters = const [],
    this.optional = 0,
    this.typeParameters = const {},
    this.namedParameters = const {},
    this.optionalNames = const {},
    this.constant = false,
    this.number,
    this.integer,
    this.isType = false,
    this.callable = false,
    this.documentation,
    this.file = '',
    this.line = 0,
    this.column = 0,
    this.offset = 0,
  });

  final String name;
  final String type;
  final List<(String, String)> parameters;
  final int optional;
  final Map<String, String> typeParameters;
  final Set<String> namedParameters;
  final Set<String> optionalNames;
  final bool constant;
  final double? number;
  final int? integer;
  final bool isType;
  final bool callable;
  final String? documentation;
  final String file;
  final int line;
  final int column;
  final int offset;
}

/// Signature and documentation comments for one SDK name.
String describeDartTop(DartTop top) =>
    _withDoc(dartTopHead(top), top.documentation);

String _formalHead(Map<String, String> formals) => formals.isEmpty
    ? ''
    : '<${formals.entries.map((p) => '${p.key}${p.value == 'Object?' ? '' : ' extends ${p.value}'}').join(', ')}>';

String dartTopHead(DartTop top) {
  if (top.isType) return 'class ${top.name}${_formalHead(top.typeParameters)}';
  if (top.callable) {
    final parameters = [
      for (final parameter in top.parameters)
        '${parameter.$1}: ${parameter.$2}',
    ].join(', ');
    return '${top.name}${_formalHead(top.typeParameters)}($parameters) -> ${top.type}';
  }
  if (top.constant) return 'const ${top.name}: ${top.type}';
  return '${top.name}: ${top.type}';
}

/// A method, getter, or constructor read from a Dart SDK source.
class DartMember {
  const DartMember({
    required this.name,
    required this.type,
    this.parameters = const [],
    this.optional = 0,
    this.typeParameters = const {},
    this.namedParameters = const {},
    this.optionalNames = const {},
    this.getter = false,
    this.documentation,
    this.file = '',
    this.line = 0,
    this.column = 0,
    this.offset = 0,
  });

  final String name;
  final String type;
  final List<(String, String)> parameters;
  final int optional;
  final Map<String, String> typeParameters;
  final Set<String> namedParameters;
  final Set<String> optionalNames;
  final bool getter;
  final String? documentation;
  final String file;
  final int line;
  final int column;
  final int offset;
}

/// Signature and documentation comments for a method, getter, or constructor.
String describeDartMember(DartMember member) =>
    _withDoc(dartMemberHead(member), member.documentation);

String dartMemberHead(DartMember member) {
  if (member.getter) return 'get ${member.name}: ${member.type}';
  final parameters = [
    for (final parameter in member.parameters)
      '${parameter.$1}: ${parameter.$2}',
  ].join(', ');
  return '${member.name}${_formalHead(member.typeParameters)}($parameters) -> ${member.type}';
}

String _withDoc(String head, String? documentation) {
  final doc = documentation?.trim();
  if (doc == null || doc.isEmpty) return head;
  return '$head\n\n$doc';
}

/// Public members of one Dart SDK class, including names inherited from its
/// sources in the same library.
class DartShape {
  const DartShape(
    this.members,
    this.constructors,
    this.statics, {
    this.listElement,
    this.supertypes = const {},
    this.name = '',
    this.typeParameters = const {},
    this.instantiatedSupertypes = const {},
  });

  final String name;
  final Map<String, String> typeParameters;
  final Set<String> instantiatedSupertypes;
  bool get typedStorage =>
      name == 'TypedData' ||
      name == 'ByteBuffer' ||
      supertypes.any(
        (item) => item == 'TypedData' || item.endsWith('.TypedData'),
      );
  final String? listElement;
  final Set<String> supertypes;
  final Map<String, DartMember> members;
  final Map<String, DartMember> constructors;
  final Map<String, DartMember> statics;
}

String substituteDartType(String type, Map<String, String> arguments) =>
    type.replaceAllMapped(
      RegExp(r'[A-Za-z_][A-Za-z0-9_]*'),
      (match) => arguments[match[0]] ?? match[0]!,
    );

DartMember instantiateDartMember(
  DartMember member,
  Map<String, String> arguments,
) {
  final scoped = Map<String, String>.of(arguments)
    ..removeWhere((key, _) => member.typeParameters.containsKey(key));
  String type(String raw) => substituteDartType(raw, scoped);
  return DartMember(
    name: member.name,
    type: type(member.type),
    parameters: [for (final p in member.parameters) (p.$1, type(p.$2))],
    optional: member.optional,
    getter: member.getter,
    typeParameters: {
      for (final p in member.typeParameters.entries) p.key: type(p.value),
    },
    namedParameters: member.namedParameters,
    optionalNames: member.optionalNames,
    documentation: member.documentation,
    file: member.file,
    line: member.line,
    column: member.column,
    offset: member.offset,
  );
}

Map<String, String> dartClassArguments(DartShape shape, String instance) {
  final open = instance.indexOf('<');
  final arguments = open < 0
      ? <String>[]
      : splitTypeList(instance.substring(open + 1, instance.length - 1));
  final result = <String, String>{};
  var index = 0;
  for (final parameter in shape.typeParameters.entries) {
    result[parameter.key] = index < arguments.length
        ? arguments[index]
        : substituteDartType(parameter.value, result);
    index++;
  }
  return result;
}

DartShape instantiateDartShape(DartShape shape, String instance) {
  final arguments = dartClassArguments(shape, instance);
  Map<String, DartMember> members(Map<String, DartMember> source) => {
        for (final e in source.entries)
          e.key: instantiateDartMember(e.value, arguments),
      };
  return DartShape(
    members(shape.members),
    members(shape.constructors),
    members(shape.statics),
    name: shape.name,
    typeParameters: shape.typeParameters,
    listElement: shape.listElement == null
        ? null
        : substituteDartType(shape.listElement!, arguments),
    supertypes: shape.supertypes,
    instantiatedSupertypes: shape.instantiatedSupertypes
        .map((s) => substituteDartType(s, arguments))
        .toSet(),
  );
}

/// The public surface of one `dart:` library.
class DartSurface {
  const DartSurface(this.names, this.types,
      {this.declarationLibraries = const {}, this.libraryUris = const {}});

  final Map<String, DartTop> names;
  final Map<String, DartShape> types;
  final Map<String, String> declarationLibraries;
  final Map<String, String> libraryUris;
}

/// Preserve source metadata while giving external signature types a library identity.
DartSurface mapDartSurfaceTypes(
  DartSurface surface,
  String Function(String) type,
) {
  DartMember member(DartMember source) => DartMember(
        name: source.name,
        type: type(source.type),
        parameters: [for (final p in source.parameters) (p.$1, type(p.$2))],
        optional: source.optional,
        typeParameters: {
          for (final e in source.typeParameters.entries) e.key: type(e.value),
        },
        namedParameters: source.namedParameters,
        optionalNames: source.optionalNames,
        getter: source.getter,
        documentation: source.documentation,
        file: source.file,
        line: source.line,
        column: source.column,
        offset: source.offset,
      );
  Map<String, DartMember> members(Map<String, DartMember> source) => {
        for (final entry in source.entries) entry.key: member(entry.value),
      };
  return DartSurface(
    {
      for (final entry in surface.names.entries)
        entry.key: DartTop(
          name: entry.value.name,
          type: type(entry.value.type),
          parameters: [
            for (final p in entry.value.parameters) (p.$1, type(p.$2)),
          ],
          optional: entry.value.optional,
          typeParameters: {
            for (final e in entry.value.typeParameters.entries)
              e.key: type(e.value),
          },
          namedParameters: entry.value.namedParameters,
          optionalNames: entry.value.optionalNames,
          constant: entry.value.constant,
          number: entry.value.number,
          integer: entry.value.integer,
          isType: entry.value.isType,
          callable: entry.value.callable,
          documentation: entry.value.documentation,
          file: entry.value.file,
          line: entry.value.line,
          column: entry.value.column,
          offset: entry.value.offset,
        ),
    },
    {
      for (final entry in surface.types.entries)
        entry.key: DartShape(
          members(entry.value.members),
          members(entry.value.constructors),
          members(entry.value.statics),
          name: entry.value.name,
          typeParameters: {
            for (final e in entry.value.typeParameters.entries)
              e.key: type(e.value),
          },
          instantiatedSupertypes:
              entry.value.instantiatedSupertypes.map(type).toSet(),
          listElement: entry.value.listElement == null
              ? null
              : type(entry.value.listElement!),
          supertypes: entry.value.supertypes.map(type).toSet(),
        ),
    },
    declarationLibraries: surface.declarationLibraries,
    libraryUris: surface.libraryUris,
  );
}

class _Cached {
  _Cached(this.stamp, this.surface, this.files);

  final String stamp;
  final DartSurface surface;
  final List<String> files;
}

final _cache = <String, _Cached>{};

/// The Dart SDK that belongs to the `dart` executable running this compiler.
String? dartSdkRoot() {
  final candidates = <String>[];
  void add(String? path) {
    if (path == null || path.isEmpty) return;
    candidates.add(path);
  }

  final executable = File(Platform.resolvedExecutable);
  add(executable.parent.parent.path);
  add(Platform.environment['DART_SDK']);
  final flutter = Platform.environment['FLUTTER_ROOT'];
  if (flutter != null && flutter.isNotEmpty) {
    add('$flutter/bin/cache/dart-sdk');
  }
  for (final root in candidates) {
    if (File('$root/lib/core/core.dart').existsSync()) return root;
  }
  return null;
}

final _libraryNames = <String, (String, List<String>)>{};

/// Public `dart:` library names present in the SDK `lib` directory.
List<String> dartLibraryNames({String? sdkRoot}) {
  final root = sdkRoot ?? dartSdkRoot();
  if (root == null) return const [];
  final lib = Directory('$root/lib');
  if (!lib.existsSync()) return const [];
  final stat = lib.statSync();
  final stamp = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
  final cached = _libraryNames[root];
  if (cached != null && cached.$1 == stamp) return cached.$2;
  final names = <String>[];
  for (final entity in lib.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('_') || name.startsWith('.')) continue;
    if (entity is File) {
      if (!name.endsWith('.dart')) continue;
      final stem = name.substring(0, name.length - 5);
      if (stem.isEmpty || stem.startsWith('_')) continue;
      names.add(stem);
    } else if (entity is Directory &&
        File('${entity.path}${Platform.pathSeparator}$name.dart')
            .existsSync()) {
      names.add(name);
    }
  }
  names.sort();
  _libraryNames[root] = (stamp, names);
  return names;
}

/// The library file for a `dart:` URI, such as `dart:math`.
File? dartLibraryFile(String uri, {String? sdkRoot}) {
  if (!uri.startsWith('dart:') || uri.startsWith('dart:_')) return null;
  final root = sdkRoot ?? dartSdkRoot();
  if (root == null) return null;
  final name = uri.substring(5);
  if (name.isEmpty || name.contains('/') || name.contains('\\')) return null;
  final nested = File('$root/lib/$name/$name.dart');
  final file = nested.existsSync() ? nested : File('$root/lib/$name.dart');
  if (!file.existsSync()) return null;
  return file;
}

/// Public names of [uri], read from the SDK sources.
///
/// The result follows those files. A later call reads them again when a
/// library file or a `part` file has changed.
DartSurface? readDartLibrary(String uri, {String? sdkRoot}) {
  final file = dartLibraryFile(uri, sdkRoot: sdkRoot);
  if (file == null) return null;
  return readDartFile(file);
}

/// Public names of one Dart library file, including its `part` and `export` files.
DartSurface? readDartFile(File file, {String? from}) {
  if (!file.existsSync()) return null;
  final key =
      '${file.absolute.path}|${from == null ? "" : packageRoot(from)?.directory ?? from}';
  final cached = _cache[key];
  if (cached != null && _stamp(cached.files) == cached.stamp) {
    return cached.surface;
  }
  final loaded = _load(file, from: from);
  _cache[key] = _Cached(_stamp(loaded.files), loaded.surface, loaded.files);
  return loaded.surface;
}

String _stamp(List<String> files) {
  final buffer = StringBuffer();
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      buffer.write('$path:missing;');
      continue;
    }
    final stat = file.statSync();
    buffer.write('$path:${stat.modified.microsecondsSinceEpoch}:${stat.size};');
  }
  return buffer.toString();
}

class _Loaded {
  _Loaded(this.surface, this.files);

  final DartSurface surface;
  final List<String> files;
}

_Loaded _load(File entry, {String? from}) {
  final classes = <String, _Class>{};
  final names = <String, DartTop>{};
  final aliases = <String, (Map<String, String>, String)>{};
  final declarationLibraries = <String, String>{};
  final libraryUris = <String, String>{};
  final files = <String>[];
  final contextRoot = from == null ? null : packageRoot(from);
  if (contextRoot != null) {
    final config =
        File('${contextRoot.directory}/.dart_tool/package_config.json');
    if (config.existsSync()) files.add(config.path);
  }
  final seen = <String>{};
  final visibleNames = <String, Map<String, DartTop>>{};
  final visibleClasses = <String, Map<String, _Class>>{};

  void load(File file, {String? owner}) {
    final path = file.absolute.uri.normalizePath().toFilePath();
    declarationLibraries[path] = owner ?? path;
    if (!file.existsSync()) return;
    if (!seen.add(path)) {
      names.addAll(visibleNames[path] ?? const {});
      classes.addAll(visibleClasses[path] ?? const {});
      return;
    }
    files.add(path);
    final priorNames = Map<String, DartTop>.of(names);
    final priorClasses = Map<String, _Class>.of(classes);
    final _Parser parser;
    try {
      parser = _Parser(
        _scan(file.readAsStringSync()),
        classes,
        names,
        path,
        aliases,
      )..parse();
    } catch (_) {
      return;
    }
    final exportedNames = <String, DartTop>{
      for (final entry in names.entries)
        if (!identical(priorNames[entry.key], entry.value))
          entry.key: entry.value,
    };
    final exportedClasses = <String, _Class>{
      for (final entry in classes.entries)
        if (!identical(priorClasses[entry.key], entry.value))
          entry.key: entry.value,
    };
    visibleNames[path] = exportedNames;
    visibleClasses[path] = exportedClasses;
    final directory = File(path).parent.path;
    for (final part in parser.parts) {
      final target =
          File('$directory/$part').absolute.uri.normalizePath().toFilePath();
      load(File(target), owner: owner ?? path);
      exportedNames.addAll(visibleNames[target] ?? const {});
      exportedClasses.addAll(visibleClasses[target] ?? const {});
    }
    for (final directive in parser.exports) {
      final exported = directive.$1;
      final beforeNames = Map<String, DartTop>.of(names);
      final beforeClasses = Map<String, _Class>.of(classes);
      File? resolved;
      if (exported.startsWith('dart:')) {
        final target = embeddedDartFile(from ?? path, exported) ??
            dartLibraryFile(exported);
        resolved = target;
        if (target != null) {
          libraryUris[target.absolute.uri.normalizePath().toFilePath()] =
              exported;
          load(target);
        }
      } else if (exported.startsWith('package:')) {
        var target = packageDartFile(from ?? path, exported);
        final root = packageRoot(path);
        final rest = exported.substring('package:'.length);
        final slash = rest.indexOf('/');
        if (target == null &&
            root != null &&
            slash > 0 &&
            rest.substring(0, slash) == root.name) {
          target = File('${root.directory}/lib/${rest.substring(slash + 1)}');
        }
        resolved = target;
        if (target != null) load(target);
      } else {
        resolved = File('$directory/$exported');
        load(resolved);
      }
      bool keeps(String name) =>
          (directive.$2.isEmpty || directive.$2.contains(name)) &&
          !directive.$3.contains(name);
      if (resolved != null) {
        final target = resolved.absolute.uri.normalizePath().toFilePath();
        exportedNames.addAll({
          for (final entry
              in (visibleNames[target] ?? <String, DartTop>{}).entries)
            if (keeps(entry.key)) entry.key: entry.value
        });
        exportedClasses.addAll({
          for (final entry
              in (visibleClasses[target] ?? <String, _Class>{}).entries)
            if (keeps(entry.key)) entry.key: entry.value
        });
      }
      if (directive.$2.isNotEmpty || directive.$3.isNotEmpty) {
        for (final name in names.keys.toList()) {
          if (keeps(name) || identical(names[name], beforeNames[name]))
            continue;
          if (beforeNames.containsKey(name))
            names[name] = beforeNames[name]!;
          else
            names.remove(name);
        }
        // Hidden bases still provide inherited signatures, but cannot replace
        // an already visible, unrelated class with the same spelling.
        for (final name in beforeClasses.keys) {
          if (!keeps(name)) classes[name] = beforeClasses[name]!;
        }
      }
    }
  }

  load(entry);
  final visiting = <String>{};
  void inherit(_Class type) {
    if (!visiting.add(type.name)) return;
    final declaredMembers = type.members.keys.toSet();
    for (final parent in type.supers) {
      final open = parent.indexOf('<');
      final name = open < 0 ? parent : parent.substring(0, open);
      final base = classes[name] ?? classes[name.split('.').last];
      if (base == null) continue;
      if (name.contains('.')) {
        final normalized =
            '${base.name}${open < 0 ? '' : parent.substring(open)}';
        type.instantiatedSupers.remove(parent);
        type.instantiatedSupers.add(normalized);
        type.superNames.add(base.name);
      }
      inherit(base);
      final arguments = open < 0
          ? <String>[]
          : splitTypeList(parent.substring(open + 1, parent.length - 1));
      final substitution = <String, String>{};
      var index = 0;
      for (final parameter in base.typeParameters.entries) {
        substitution[parameter.key] = index < arguments.length
            ? arguments[index]
            : substituteDartType(parameter.value, substitution);
        index++;
      }
      if (base.listElement != null)
        type.listElement ??= substituteDartType(
          base.listElement!,
          substitution,
        );
      type.superNames.addAll(base.superNames);
      type.instantiatedSupers.addAll(
        base.instantiatedSupers.map((s) => substituteDartType(s, substitution)),
      );
      for (final entry in type.constructors.entries.toList()) {
        final source = entry.value;
        final defaults =
            base.constructors['']?.parameters ?? const <(String, String)>[];
        var superPosition = 0;
        final positionalDefaults = defaults
            .where((p) =>
                !(base.constructors['']?.namedParameters.contains(p.$1) ??
                    false))
            .toList();
        String forwarded(String raw, bool named) {
          if (!raw.startsWith('@super.')) return raw;
          final name = raw.substring('@super.'.length);
          String? resolved;
          if (!named && superPosition < positionalDefaults.length) {
            resolved = positionalDefaults[superPosition++].$2;
          }
          for (final parameter in defaults) {
            if (named && parameter.$1 == name) resolved = parameter.$2;
          }
          resolved ??= base.fields[name];
          return resolved == null
              ? raw
              : substituteDartType(resolved, substitution);
        }

        type.constructors[entry.key] = DartMember(
            name: source.name,
            type: source.type,
            parameters: [
              for (final p in source.parameters)
                (p.$1, forwarded(p.$2, source.namedParameters.contains(p.$1)))
            ],
            optional: source.optional,
            getter: source.getter,
            typeParameters: source.typeParameters,
            namedParameters: source.namedParameters,
            optionalNames: source.optionalNames,
            documentation: source.documentation,
            file: source.file,
            line: source.line,
            column: source.column,
            offset: source.offset);
      }
      for (final entry in base.members.entries) {
        final member = instantiateDartMember(entry.value, substitution);
        if (type.implementationSupers.contains(parent) &&
            !declaredMembers.contains(entry.key)) {
          type.members[entry.key] = member;
        } else {
          type.members.putIfAbsent(entry.key, () => member);
        }
      }
    }
  }

  for (final type in classes.values) {
    inherit(type);
  }
  // Top-level class calls must use the finalized constructor signature too.
  for (final type in classes.values) {
    final top = names[type.name];
    final constructor = type.constructors[''];
    if (!type.public || top == null || constructor == null) continue;
    names[type.name] = DartTop(
        name: top.name,
        type: top.type,
        parameters: constructor.parameters,
        optional: constructor.optional,
        typeParameters: top.typeParameters,
        namedParameters: constructor.namedParameters,
        optionalNames: constructor.optionalNames,
        constant: top.constant,
        number: top.number,
        integer: top.integer,
        isType: top.isType,
        callable: top.callable,
        documentation: top.documentation,
        file: top.file,
        line: top.line,
        column: top.column,
        offset: top.offset);
  }
  final types = <String, DartShape>{
    for (final type in classes.values)
      if (type.public)
        type.name: DartShape(
          Map<String, DartMember>.of(type.members),
          Map<String, DartMember>.of(type.constructors),
          Map<String, DartMember>.of(type.statics),
          name: type.name,
          typeParameters: type.typeParameters,
          instantiatedSupertypes: type.instantiatedSupers,
          listElement: type.listElement,
          supertypes: Set<String>.of(type.superNames),
        ),
  };
  final expandedTypes = <String, String>{};
  String expand(String type, [Set<String> active = const {}]) {
    if (active.isEmpty && expandedTypes.containsKey(type))
      return expandedTypes[type]!;
    var result = type;
    for (final entry in aliases.entries) {
      if (active.contains(entry.key) || !result.contains(entry.key)) continue;
      final pattern = RegExp(
          '\\b${RegExp.escape(entry.key)}(?:<([^<>]*(?:<[^<>]*>[^<>]*)*)>)?(\\?)?');
      result = result.replaceAllMapped(pattern, (match) {
        final supplied = match.group(1) == null
            ? <String>[]
            : splitTypeList(match.group(1)!);
        final substitutions = <String, String>{};
        var index = 0;
        for (final p in entry.value.$1.entries) {
          substitutions[p.key] =
              index < supplied.length ? supplied[index] : p.value;
          index++;
        }
        final resolved = expand(
            substituteDartType(entry.value.$2, substitutions),
            {...active, entry.key});
        return match.group(2) == null ? resolved : nullableType(resolved);
      });
    }
    return result;
  }

  final surface = DartSurface(names, types,
      declarationLibraries: declarationLibraries, libraryUris: libraryUris);
  return _Loaded(mapDartSurfaceTypes(surface, expand), files);
}

class _Class {
  _Class(this.name, this.public);

  final String name;
  final bool public;
  final typeParameters = <String, String>{};
  final supers = <String>[];
  final implementationSupers = <String>{};
  var hasConstructor = false;
  final instantiatedSupers = <String>{};
  final superNames = <String>{};
  String? listElement;
  final members = <String, DartMember>{};
  final constructors = <String, DartMember>{};
  final statics = <String, DartMember>{};
  final fields = <String, String>{};
}

class _Tok {
  _Tok(this.text, this.kind, this.line, this.column, this.offset, [this.doc]);

  final String text;

  /// `i` identifier, `n` number, `s` string, `p` punctuation.
  final String kind;
  final int line;
  final int column;
  final int offset;
  final String? doc;
}

/// `///` comments on the line immediately above a declaration.
Map<int, String> _documentationLines(String source) {
  final result = <int, String>{};
  final lines = source.split('\n');
  final pending = <String>[];
  var live = false;
  for (var n = 0; n < lines.length; n++) {
    final trimmed = lines[n].trimLeft();
    if (trimmed.startsWith('///')) {
      if (!live) pending.clear();
      var text = trimmed.substring(3);
      if (text.startsWith(' ')) text = text.substring(1);
      pending.add(text);
      live = true;
      continue;
    }
    if (trimmed.isEmpty ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/*') ||
        trimmed.startsWith('*')) {
      pending.clear();
      live = false;
      continue;
    }
    if (pending.isNotEmpty) result[n + 1] = pending.join('\n').trim();
    pending.clear();
    live = false;
  }
  return result;
}

List<_Tok> _scan(String source) {
  final tokens = <_Tok>[];
  final docs = _documentationLines(source);
  var i = 0;
  final n = source.length;
  var line = 1;
  var column = 1;
  var placed = 0;
  var bytes = 0;

  void place(int index) {
    while (placed < index && placed < n) {
      final unit = source.codeUnitAt(placed);
      if (unit == 10) {
        line++;
        column = 1;
        bytes++;
      } else if (unit == 13) {
        bytes++;
      } else if (unit < 0x80) {
        column++;
        bytes++;
      } else if (unit < 0x800) {
        column++;
        bytes += 2;
      } else if (unit >= 0xD800 && unit <= 0xDBFF) {
        column++;
        bytes += 4;
        if (placed + 1 < index && placed + 1 < n) placed++;
      } else {
        column++;
        bytes += 3;
      }
      placed++;
    }
  }

  void emit(String text, String kind, int start) {
    place(start);
    tokens.add(_Tok(text, kind, line, column, bytes, docs[line]));
  }

  bool digit(int index) =>
      index < n &&
      source.codeUnitAt(index) >= 48 &&
      source.codeUnitAt(index) <= 57;
  bool ident(int index) {
    if (index >= n) return false;
    final unit = source.codeUnitAt(index);
    return unit == 95 ||
        unit == 36 ||
        (unit >= 65 && unit <= 90) ||
        (unit >= 97 && unit <= 122) ||
        (unit >= 48 && unit <= 57);
  }

  void string(String quote, bool raw, bool triple) {
    final start = i;
    i += triple ? 3 : 1;
    while (i < n) {
      if (!raw && source[i] == r'\') {
        i += i + 1 < n ? 2 : 1;
        continue;
      }
      if (!raw && source[i] == r'$') {
        i++;
        if (i < n && source[i] == '{') {
          var depth = 0;
          while (i < n) {
            if (source[i] == '{') {
              depth++;
              i++;
            } else if (source[i] == '}') {
              depth--;
              i++;
              if (depth == 0) break;
            } else if (source[i] == "'" || source[i] == '"') {
              final mark = source[i];
              final long =
                  i + 2 < n && source[i + 1] == mark && source[i + 2] == mark;
              string(mark, false, long);
            } else {
              i++;
            }
          }
        } else {
          while (ident(i)) {
            i++;
          }
        }
        continue;
      }
      if (triple && i + 2 < n && source.startsWith(quote * 3, i)) {
        i += 3;
        break;
      }
      if (!triple && source[i] == quote) {
        i++;
        break;
      }
      i++;
    }
    final open = triple ? 3 : 1;
    final close = i - start >= open && source.startsWith(quote * open, i - open)
        ? open
        : 0;
    final body = source.substring(start + open, i - close);
    emit(body, 's', start);
  }

  while (i < n) {
    final unit = source.codeUnitAt(i);
    if (unit <= 32) {
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      i += 2;
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
      i += 2;
      while (i + 1 < n && !source.startsWith('*/', i)) {
        i++;
      }
      i += i + 1 < n ? 2 : 1;
      continue;
    }
    if (source[i] == 'r' &&
        i + 1 < n &&
        (source[i + 1] == "'" || source[i + 1] == '"')) {
      final quote = source[i + 1];
      final triple =
          i + 3 < n && source[i + 2] == quote && source[i + 3] == quote;
      i++;
      string(quote, true, triple);
      continue;
    }
    if (source[i] == "'" || source[i] == '"') {
      final quote = source[i];
      final triple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      string(quote, false, triple);
      continue;
    }
    if (digit(i)) {
      final start = i;
      while (digit(i)) {
        i++;
      }
      if (i < n && source[i] == '.' && digit(i + 1)) {
        i++;
        while (digit(i)) {
          i++;
        }
      }
      if (i < n && (source[i] == 'e' || source[i] == 'E')) {
        final mark = i;
        var j = i + 1;
        if (j < n && (source[j] == '+' || source[j] == '-')) j++;
        if (digit(j)) {
          i = j;
          while (digit(i)) {
            i++;
          }
        } else {
          i = mark;
        }
      }
      emit(source.substring(start, i), 'n', start);
      continue;
    }
    if (ident(i) && !digit(i)) {
      final start = i;
      while (ident(i)) {
        i++;
      }
      emit(source.substring(start, i), 'i', start);
      continue;
    }
    emit(source[i], 'p', i);
    i++;
  }
  return tokens;
}

class _Parser {
  _Parser(this.tokens, this.classes, this.names, this.file, this.aliases);
  final Map<String, (Map<String, String>, String)> aliases;

  final List<_Tok> tokens;
  final Map<String, _Class> classes;
  final Map<String, DartTop> names;
  final String file;
  final parts = <String>[];
  final exports = <(String, Set<String>, Set<String>)>[];
  var i = 0;

  String get peek => i < tokens.length ? tokens[i].text : '';

  bool get isIdent => i < tokens.length && tokens[i].kind == 'i';

  String take() {
    final text = peek;
    if (i < tokens.length) i++;
    return text;
  }

  String? get _doc => i < tokens.length ? tokens[i].doc : null;

  _Tok? get _here => i < tokens.length ? tokens[i] : null;

  DartMember _noted(
    String name,
    String type,
    _Tok? at,
    String? doc, {
    List<(String, String)> parameters = const [],
    int optional = 0,
    Map<String, String> typeParameters = const {},
    Set<String> namedParameters = const {},
    Set<String> optionalNames = const {},
    bool getter = false,
  }) {
    return DartMember(
      name: name,
      type: type,
      parameters: parameters,
      optional: optional,
      typeParameters: typeParameters,
      namedParameters: namedParameters,
      optionalNames: optionalNames,
      getter: getter,
      documentation: doc,
      file: file,
      line: at?.line ?? 0,
      column: at?.column ?? 0,
      offset: at?.offset ?? 0,
    );
  }

  void parse() {
    while (i < tokens.length) {
      final before = i;
      _top();
      if (i == before) i++;
    }
  }

  String? _declarationDoc;

  void _top() {
    _declarationDoc = _doc;
    _meta();
    if (i >= tokens.length) return;
    if (peek == 'import' ||
        peek == 'export' ||
        peek == 'part' ||
        peek == 'library') {
      _directive();
      return;
    }
    if (peek == 'typedef') {
      take();
      final name = isIdent ? take() : '';
      final parameters = peek == '<' ? _typeParameters() : <String, String>{};
      if (peek == '=') {
        take();
        final type = _rawType();
        if (name.isNotEmpty && !type.startsWith('@unsupported')) {
          aliases[name] = (parameters, type);
        }
      }
      _skipStatement();
      return;
    }
    if (peek == 'extension') {
      _skipBody();
      return;
    }
    if (peek == 'enum') {
      _enum();
      return;
    }
    final modifiers = _modifiers();
    if (peek == 'class' || peek == 'mixin') {
      _type(modifiers);
      return;
    }
    _value(modifiers);
  }

  void _directive() {
    final kind = take();
    if (kind == 'part' && peek == 'of') {
      _skipStatement();
      return;
    }
    String? uri;
    final shown = <String>{};
    final hidden = <String>{};
    Set<String>? filter;
    while (i < tokens.length && peek != ';') {
      if (tokens[i].kind == 's' && uri == null)
        uri = tokens[i].text;
      else if (peek == 'show')
        filter = shown;
      else if (peek == 'hide')
        filter = hidden;
      else if (filter != null && isIdent) filter.add(peek);
      i++;
    }
    if (peek == ';') i++;
    if (uri == null ||
        (uri.contains(':') &&
            !uri.startsWith('package:') &&
            !uri.startsWith('dart:')) ||
        uri.contains('\\')) return;
    if (kind == 'part') parts.add(uri);
    if (kind == 'export') exports.add((uri, shown, hidden));
  }

  void _enum() {
    take();
    if (!isIdent) {
      _skipBody();
      return;
    }
    final at = _here;
    final name = take();
    final type = _Class(name, !name.startsWith('_'));
    classes[name] = type;
    while (i < tokens.length && peek != '{' && peek != ';') {
      i++;
    }
    if (peek != '{') return;
    i++;
    while (i < tokens.length && peek != '}' && peek != ';') {
      _meta();
      if (isIdent && !peek.startsWith('_')) {
        final at = _here;
        final value = take();
        type.statics[value] = _noted(
          value,
          name,
          at,
          _declarationDoc,
          getter: true,
        );
      }
      while (i < tokens.length && peek != ',' && peek != ';' && peek != '}') {
        if (peek == '(') {
          _group('(', ')');
        } else {
          i++;
        }
      }
      if (peek == ',') i++;
    }
    if (peek == ';') {
      i++;
      _members(type, {name: name});
    }
    if (peek == '}') i++;
    if (type.public) {
      names[name] = DartTop(
        name: name,
        type: name,
        isType: true,
        documentation: _declarationDoc,
        file: file,
        line: at?.line ?? 0,
        column: at?.column ?? 0,
        offset: at?.offset ?? 0,
      );
    }
  }

  void _type(Set<String> modifiers) {
    final kind = take();
    if (!isIdent) {
      _skipBody();
      return;
    }
    final at = _here;
    final name = take();
    final type = _Class(name, !name.startsWith('_'));
    classes[name] = type;
    final params = peek == '<' ? _typeParameters() : <String, String>{};
    type.typeParameters.addAll(params);
    while (i < tokens.length && peek != '{' && peek != ';') {
      if (peek == 'extends' ||
          peek == 'with' ||
          peek == 'on' ||
          peek == 'implements') {
        final edgeKind = take();
        while (i < tokens.length &&
            peek != '{' &&
            peek != ';' &&
            peek != 'with' &&
            peek != 'implements' &&
            peek != 'on') {
          final raw = _rawType();
          final head = _head(raw);
          if (head.isNotEmpty && edgeKind != 'on') {
            if (edgeKind == 'extends' || edgeKind == 'with')
              type.implementationSupers.add(raw);
            type.supers.add(raw);
            type.instantiatedSupers.add(raw);
            type.superNames.add(head);
          }
          final list =
              RegExp(r'^(?:List|TypedDataList)<(.+)>$').firstMatch(raw);
          if (list != null)
            type.listElement = _simplify(list.group(1)!, params);
          if (peek == ',') {
            i++;
            continue;
          }
          break;
        }
      } else {
        i++;
      }
    }
    if (peek == '{') {
      i++;
      _members(type, params);
    }
    if (peek == '}') i++;
    if (!type.hasConstructor &&
        kind == 'class' &&
        !modifiers.contains('abstract') &&
        !modifiers.contains('sealed'))
      type.constructors[''] = _noted(type.name, type.name, at, _declarationDoc);
    for (final entry in type.constructors.entries.toList()) {
      final m = entry.value;
      type.constructors[entry.key] = DartMember(
          name: m.name,
          type: m.type,
          parameters: [
            for (final p in m.parameters)
              (
                p.$1,
                p.$2.startsWith('@field.')
                    ? type.fields[p.$2.substring(7)] ??
                        '@unsupported.initializingFormal'
                    : p.$2
              )
          ],
          optional: m.optional,
          typeParameters: m.typeParameters,
          namedParameters: m.namedParameters,
          optionalNames: m.optionalNames,
          getter: m.getter,
          documentation: m.documentation,
          file: m.file,
          line: m.line,
          column: m.column,
          offset: m.offset);
    }
    if (!type.public) return;
    final unnamed = type.constructors[''];
    names[name] = DartTop(
      name: name,
      type: name,
      isType: true,
      callable: unnamed != null,
      parameters: unnamed?.parameters ?? const [],
      optional: unnamed?.optional ?? 0,
      typeParameters: params,
      namedParameters: unnamed?.namedParameters ?? const {},
      optionalNames: unnamed?.optionalNames ?? const {},
      documentation: _declarationDoc,
      file: file,
      line: at?.line ?? 0,
      column: at?.column ?? 0,
      offset: at?.offset ?? 0,
    );
  }

  void _members(_Class type, Map<String, String> params) {
    while (i < tokens.length && peek != '}') {
      final before = i;
      final doc = _doc;
      _meta();
      if (peek == '}' || i >= tokens.length) break;
      if (peek == ';') {
        i++;
        continue;
      }
      final modifiers = _modifiers();
      if (peek == '}') break;
      final isStatic = modifiers.contains('static');
      if (_constructor(type, params, doc)) {
        if (i == before) i++;
        continue;
      }
      if (peek == 'operator') {
        _skipMember();
        if (i == before) i++;
        continue;
      }
      String? leading;
      if (peek != 'get' && peek != 'set' && peek != 'operator') {
        leading = _rawType();
      }
      if (leading != null && peek == 'operator') {
        take();
        final at = _here;
        var operator = '';
        while (i < tokens.length && peek != '(' && peek != ';' && peek != '}') {
          operator += take();
        }
        if (peek == '(') {
          final signature = _parameters(params, type.fields);
          final key =
              operator == '-' && signature.$1.isEmpty ? 'unary-' : operator;
          type.members[key] = _noted(
            operator,
            _simplify(leading, params),
            at,
            doc,
            parameters: signature.$1,
            optional: signature.$2,
          );
        }
        _skipMember();
        if (i == before) i++;
        continue;
      }
      if (peek == 'get' || peek == 'set') {
        final kind = take();
        final at = _here;
        final member = isIdent ? take() : '';
        if (member.isEmpty || member.startsWith('_')) {
          _skipMember();
        } else if (kind == 'get') {
          final shown = _simplify(leading ?? 'dynamic', params);
          final dart = _noted(member, shown, at, doc, getter: true);
          if (isStatic) {
            type.statics[member] = dart;
          } else {
            type.members[member] = dart;
            type.fields[member] = shown;
          }
          _skipMember();
        } else {
          _skipMember();
        }
        if (i == before) i++;
        continue;
      }
      if (leading == null) {
        _skipMember();
        if (i == before) i++;
        continue;
      }
      if (!isIdent) {
        _skipMember();
        if (i == before) i++;
        continue;
      }
      final at = _here;
      final member = take();
      final own = peek == '<' ? _typeParameters() : const <String, String>{};
      final scope = {...params, ...own};
      if (member.startsWith('_')) {
        if (peek != '(' && !isStatic)
          type.fields[member] = _simplify(leading, scope);
        _skipMember();
        if (i == before) i++;
        continue;
      }
      if (peek == '(') {
        final signature = _parameters(scope, type.fields);
        final dart = _noted(
          member,
          _simplify(leading, scope),
          at,
          doc,
          typeParameters: own,
          parameters: signature.$1,
          optional: signature.$2,
          namedParameters: signature.$3,
          optionalNames: signature.$4,
        );
        if (isStatic) {
          type.statics[member] = dart;
        } else {
          type.members[member] = dart;
        }
      } else {
        final shown = _simplify(leading, scope);
        final dart = _noted(member, shown, at, doc, getter: true);
        if (isStatic) {
          type.statics[member] = dart;
        } else {
          type.members[member] = dart;
          type.fields[member] = shown;
        }
      }
      _skipMember();
      if (i == before) i++;
    }
  }

  bool _constructor(_Class type, Map<String, String> params, String? doc) {
    if (!isIdent || peek != type.name) return false;
    final saved = i;
    final ownerAt = _here;
    take();
    if (peek == '<') _group('<', '>');
    var name = '';
    var at = ownerAt;
    if (peek == '.') {
      i++;
      if (!isIdent) {
        i = saved;
        return false;
      }
      at = _here;
      name = take();
    }
    if (peek != '(') {
      i = saved;
      return false;
    }
    type.hasConstructor = true;
    if (name.startsWith('_')) {
      _skipMember();
      return true;
    }
    final signature = _parameters(params, type.fields);
    type.constructors[name] = _noted(
      name.isEmpty ? type.name : name,
      type.name,
      at,
      doc,
      parameters: signature.$1,
      optional: signature.$2,
      namedParameters: signature.$3,
      optionalNames: signature.$4,
    );
    _skipMember();
    return true;
  }

  void _value(Set<String> modifiers) {
    if (i >= tokens.length) return;
    final raw = _rawType();
    // A top-level setter has no return type and must not overwrite its getter.
    if (raw == 'set' && isIdent) {
      _skipMember();
      return;
    }
    if (!isIdent) {
      _skipMember();
      return;
    }
    var at = _here;
    var name = take();
    if (name == 'get' && isIdent) {
      at = _here;
      name = take();
    } else if (name == 'set' && isIdent) {
      _skipMember();
      return;
    }
    final params = peek == '<' ? _typeParameters() : const <String, String>{};
    if (name.startsWith('_')) {
      _skipMember();
      return;
    }
    if (peek == '(') {
      final signature = _parameters(params, const {});
      names[name] = DartTop(
        name: name,
        type: _simplify(raw, params),
        typeParameters: params,
        parameters: signature.$1,
        optional: signature.$2,
        namedParameters: signature.$3,
        optionalNames: signature.$4,
        callable: true,
        documentation: _declarationDoc,
        file: file,
        line: at?.line ?? 0,
        column: at?.column ?? 0,
        offset: at?.offset ?? 0,
      );
      _skipMember();
      return;
    }
    double? number;
    int? integer;
    if (peek == '=') {
      i++;
      var negative = false;
      if (peek == '-') {
        negative = true;
        i++;
      }
      if (i < tokens.length && tokens[i].kind == 'n') {
        final token = take();
        final parsed = num.tryParse(token);
        if (parsed != null) {
          final value = negative ? -parsed : parsed;
          if (raw == 'double' ||
              token.contains('.') ||
              token.contains('e') ||
              token.contains('E')) {
            number = value.toDouble();
          } else {
            integer = value.toInt();
          }
        }
      }
    }
    final shown = _simplify(raw, params);
    names[name] = DartTop(
      name: name,
      type: shown == 'dynamic' && number != null ? 'double' : shown,
      constant: modifiers.contains('const'),
      number: number,
      integer: integer,
      documentation: _declarationDoc,
      file: file,
      line: at?.line ?? 0,
      column: at?.column ?? 0,
      offset: at?.offset ?? 0,
    );
    _skipMember();
  }

  Map<String, String> _typeParameters() {
    final map = <String, String>{};
    if (peek != '<') return map;
    i++;
    while (i < tokens.length && peek != '>') {
      if (peek == ',') {
        i++;
        continue;
      }
      if (!isIdent) {
        i++;
        continue;
      }
      final name = take();
      var bound = 'Object?';
      if (peek == 'extends') {
        i++;
        bound = _rawType();
      }
      map[name] = bound;
      if (peek == ',') i++;
    }
    if (peek == '>') i++;
    return map;
  }

  (List<(String, String)>, int, Set<String>, Set<String>) _parameters(
      Map<String, String> params, Map<String, String> fields,
      {bool allowUnnamed = false}) {
    if (peek != '(') return (const [], 0, const {}, const {});
    i++;
    final list = <(String, String)>[];
    var optional = 0;
    final named = <String>{};
    final optionalNames = <String>{};
    var bracket = 0;
    var brace = 0;
    while (i < tokens.length && !(peek == ')' && bracket == 0 && brace == 0)) {
      final before = i;
      if (peek == '@') _meta();
      if (peek == '[') {
        bracket++;
        i++;
        continue;
      }
      if (peek == ']' && bracket > 0) {
        bracket--;
        i++;
        continue;
      }
      if (peek == '{') {
        brace++;
        i++;
        continue;
      }
      if (peek == '}' && brace > 0) {
        brace--;
        i++;
        continue;
      }
      if (peek == ',' || peek == ';') {
        i++;
        continue;
      }
      var required = false;
      if (peek == 'required') {
        required = true;
        i++;
      }
      if (peek == 'covariant' || peek == 'final') i++;
      String type;
      String name;
      if (peek == 'this' || peek == 'super') {
        final forwarded = peek == 'super';
        i++;
        if (peek == '.') i++;
        name = isIdent ? take() : '';
        type = forwarded ? '@super.$name' : fields[name] ?? '@field.$name';
      } else {
        final rawType = _rawType();
        type = _simplify(rawType, params);
        name = isIdent ? take() : '';
        if ((name == 'this' || name == 'super') && peek == '.') {
          take();
          name = isIdent ? take() : '';
        }
        if (name.isEmpty &&
            !allowUnnamed &&
            RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(rawType) &&
            (peek == ',' ||
                peek == ')' ||
                peek == ']' ||
                peek == '}' ||
                peek == '=')) {
          name = rawType;
          type = 'dynamic';
        }
        if (name.isNotEmpty && peek == '(') {
          final fnParams = _parameters(params, const {}, allowUnnamed: true);
          final nullableFn = peek == '?';
          if (nullableFn) i++;
          final paramTypes = [for (final p in fnParams.$1) p.$2].join(', ');
          final fnType = '($paramTypes) -> $type';
          type = nullableFn ? '($fnType)?' : fnType;
        }
      }
      if (allowUnnamed && name.isEmpty) name = '_p${list.length}';
      if (peek == '=') _skipDefault();
      if (name.isNotEmpty) {
        list.add((name, type));
        if (brace > 0) named.add(name);
        if (bracket > 0 || (brace > 0 && !required)) {
          optional++;
          optionalNames.add(name);
        }
      }
      if (i == before) i++;
    }
    if (peek == ')') i++;
    return (list, optional, named, optionalNames);
  }

  String _rawType() {
    if (i >= tokens.length) return 'dynamic';
    if (peek == '(') {
      _group('(', ')');
      if (peek == 'Function') {
        take();
        if (peek == '<') _group('<', '>');
        if (peek == '(') _group('(', ')');
      }
      if (peek == '?') i++;
      return '@unsupported.record';
    }
    if (!isIdent) return 'dynamic';
    final buffer = StringBuffer(take());
    while (peek == '.' && i + 1 < tokens.length && tokens[i + 1].kind == 'i') {
      buffer.write(take());
      buffer.write(take());
    }
    if (peek == '<') buffer.write(_angles());
    if (peek == '?') buffer.write(take());
    if (peek == 'Function') {
      take();
      final generic = peek == '<';
      if (generic) _group('<', '>');
      final signature = _parameters(const {}, const {}, allowUnnamed: true);
      final function =
          '(${nativeFunctionParameters(signature.$1, signature.$3, signature.$4)}) -> $buffer';
      final nullable = peek == '?';
      if (nullable) i++;
      if (generic) return '@unsupported.function';
      return nullable ? nullableType(function) : function;
    }
    return buffer.toString();
  }

  String _angles() {
    if (peek != '<') return '';
    final start = i;
    _group('<', '>');
    return tokens.skip(start).take(i - start).map((token) => token.text).join();
  }

  String _simplify(String raw, Map<String, String> params) {
    if (raw.isEmpty) return 'dynamic';
    final replaced = raw;
    final parsed =
        RegExp(r'^([A-Za-z_][A-Za-z0-9_.]*)(<.*>)?(\?)?$').firstMatch(replaced);
    if (parsed == null) return replaced;
    final name = parsed.group(1)!;
    final args = parsed.group(2);
    final nullable = parsed.group(3) ?? '';
    return '$name${args ?? ''}$nullable';
  }

  String _head(String raw) {
    final match = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)').firstMatch(raw);
    return match?.group(1) ?? '';
  }

  Set<String> _modifiers() {
    const header = {
      'abstract',
      'base',
      'interface',
      'sealed',
      'final',
      'mixin',
    };
    const words = {
      'external',
      'const',
      'final',
      'var',
      'late',
      'static',
      'covariant',
      'factory',
    };
    final found = <String>{};
    while (true) {
      if (header.contains(peek) && _introducesType()) {
        found.add(take());
        continue;
      }
      if (!words.contains(peek)) break;
      found.add(take());
    }
    return found;
  }

  bool _introducesType() {
    var k = i + 1;
    const skip = {'abstract', 'base', 'interface', 'sealed', 'mixin', 'final'};
    while (k < tokens.length && skip.contains(tokens[k].text)) {
      k++;
    }
    return k < tokens.length &&
        (tokens[k].text == 'class' ||
            tokens[k].text == 'mixin' ||
            tokens[k].text == 'enum');
  }

  void _meta() {
    while (peek == '@') {
      i++;
      if (isIdent) i++;
      while (peek == '.') {
        i++;
        if (isIdent) i++;
      }
      if (peek == '<') _group('<', '>');
      if (peek == '(') _group('(', ')');
    }
  }

  void _group(String open, String close) {
    if (peek != open) return;
    var depth = 0;
    while (i < tokens.length) {
      final token = tokens[i++];
      if (token.kind == 's') continue;
      final text = token.text;
      if (text == open) {
        depth++;
      } else if (text == close) {
        depth--;
        if (depth == 0) return;
      }
    }
  }

  void _skipDefault() {
    i++;
    var depth = 0;
    while (i < tokens.length) {
      final text = peek;
      if (text == '(' || text == '[' || text == '{' || text == '<') {
        depth++;
      } else if (text == ')' || text == ']' || text == '}' || text == '>') {
        if (depth == 0) return;
        depth--;
      } else if (text == ',' && depth == 0) {
        return;
      }
      i++;
    }
  }

  void _skipMember() {
    if (peek == ';') {
      i++;
      return;
    }
    if (peek == '{') {
      _group('{', '}');
      return;
    }
    var paren = 0;
    var brace = 0;
    var bracket = 0;
    while (i < tokens.length) {
      if (tokens[i].kind == 's') {
        i++;
        continue;
      }
      final text = tokens[i].text;
      if (text == '(') {
        paren++;
      } else if (text == ')') {
        if (paren == 0 && brace == 0 && bracket == 0) return;
        if (paren > 0) paren--;
      } else if (text == '{') {
        brace++;
      } else if (text == '}') {
        if (brace == 0 && paren == 0) return;
        brace--;
        if (brace == 0 && paren == 0) {
          i++;
          return;
        }
      } else if (text == '[') {
        bracket++;
      } else if (text == ']') {
        if (bracket > 0) bracket--;
      } else if (text == ';' && paren == 0 && brace == 0 && bracket == 0) {
        i++;
        return;
      }
      i++;
    }
  }

  void _skipBody() {
    while (i < tokens.length && peek != '{' && peek != ';') {
      i++;
    }
    if (peek == '{') {
      _group('{', '}');
    } else if (peek == ';') {
      i++;
    }
  }

  void _skipStatement() {
    var paren = 0;
    var brace = 0;
    while (i < tokens.length) {
      if (tokens[i].kind == 's') {
        i++;
        continue;
      }
      final text = tokens[i].text;
      if (text == '(') {
        paren++;
      } else if (text == ')') {
        if (paren > 0) paren--;
      } else if (text == '{') {
        brace++;
      } else if (text == '}') {
        if (brace == 0 && paren == 0) return;
        if (brace > 0) brace--;
      } else if (text == ';' && paren == 0 && brace == 0) {
        i++;
        return;
      }
      i++;
    }
  }
}
