import 'dart:io';

/// A public name read from a Dart SDK library source.
class DartTop {
  const DartTop({
    required this.name,
    required this.type,
    this.parameters = const [],
    this.optional = 0,
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

String dartTopHead(DartTop top) {
  if (top.isType) return 'class ${top.name}';
  if (top.callable) {
    final parameters = [
      for (final parameter in top.parameters) '${parameter.$1}: ${parameter.$2}'
    ].join(', ');
    return '${top.name}($parameters) -> ${top.type}';
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
      '${parameter.$1}: ${parameter.$2}'
  ].join(', ');
  return '${member.name}($parameters) -> ${member.type}';
}

String _withDoc(String head, String? documentation) {
  final doc = documentation?.trim();
  if (doc == null || doc.isEmpty) return head;
  return '$head\n\n$doc';
}

/// Public members of one Dart SDK class, including names inherited from its
/// sources in the same library.
class DartShape {
  const DartShape(this.members, this.constructors, this.statics);

  final Map<String, DartMember> members;
  final Map<String, DartMember> constructors;
  final Map<String, DartMember> statics;
}

/// The public surface of one `dart:` library.
class DartSurface {
  const DartSurface(this.names, this.types);

  final Map<String, DartTop> names;
  final Map<String, DartShape> types;
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
DartSurface? readDartFile(File file) {
  if (!file.existsSync()) return null;
  final key = file.absolute.path;
  final cached = _cache[key];
  if (cached != null && _stamp(cached.files) == cached.stamp) {
    return cached.surface;
  }
  final loaded = _load(file);
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

_Loaded _load(File entry) {
  final classes = <String, _Class>{};
  final names = <String, DartTop>{};
  final files = <String>[];
  final seen = <String>{};

  void load(File file) {
    final path = file.absolute.path;
    if (!seen.add(path) || !file.existsSync()) return;
    files.add(path);
    final _Parser parser;
    try {
      parser = _Parser(
        _scan(file.readAsStringSync()),
        classes,
        names,
        file.absolute.path,
      )..parse();
    } catch (_) {
      return;
    }
    final directory = file.parent.path;
    for (final part in parser.parts) {
      load(File('$directory/$part'));
    }
    for (final exported in parser.exports) {
      load(File('$directory/$exported'));
    }
  }

  load(entry);
  final visiting = <String>{};
  void inherit(_Class type) {
    if (!visiting.add(type.name)) return;
    for (final parent in type.supers) {
      final base = classes[parent];
      if (base == null) continue;
      inherit(base);
      for (final entry in base.members.entries) {
        type.members.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  for (final type in classes.values) {
    inherit(type);
  }
  final types = <String, DartShape>{
    for (final type in classes.values)
      if (type.public)
        type.name: DartShape(
          Map<String, DartMember>.of(type.members),
          Map<String, DartMember>.of(type.constructors),
          Map<String, DartMember>.of(type.statics),
        ),
  };
  return _Loaded(DartSurface(names, types), files);
}

class _Class {
  _Class(this.name, this.public);

  final String name;
  final bool public;
  final supers = <String>[];
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
  _Parser(this.tokens, this.classes, this.names, this.file);

  final List<_Tok> tokens;
  final Map<String, _Class> classes;
  final Map<String, DartTop> names;
  final String file;
  final parts = <String>[];
  final exports = <String>[];
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
    bool getter = false,
  }) {
    return DartMember(
      name: name,
      type: type,
      parameters: parameters,
      optional: optional,
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
      _type();
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
    while (i < tokens.length && peek != ';') {
      if (tokens[i].kind == 's' && uri == null) uri = tokens[i].text;
      i++;
    }
    if (peek == ';') i++;
    if (uri == null || uri.contains(':') || uri.contains('\\')) return;
    if (kind == 'part') parts.add(uri);
    if (kind == 'export') exports.add(uri);
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
        type.statics[value] =
            _noted(value, name, at, _declarationDoc, getter: true);
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

  void _type() {
    take();
    if (!isIdent) {
      _skipBody();
      return;
    }
    final at = _here;
    final name = take();
    final type = _Class(name, !name.startsWith('_'));
    classes[name] = type;
    final params = peek == '<' ? _typeParameters() : <String, String>{};
    while (i < tokens.length && peek != '{' && peek != ';') {
      if (peek == 'extends' ||
          peek == 'with' ||
          peek == 'on' ||
          peek == 'implements') {
        take();
        while (i < tokens.length &&
            peek != '{' &&
            peek != ';' &&
            peek != 'with' &&
            peek != 'implements' &&
            peek != 'on') {
          final raw = _rawType();
          final head = _head(raw);
          if (head.isNotEmpty) type.supers.add(head);
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
    if (!type.public) return;
    final unnamed = type.constructors[''];
    names[name] = DartTop(
      name: name,
      type: name,
      isType: true,
      callable: unnamed != null,
      parameters: unnamed?.parameters ?? const [],
      optional: unnamed?.optional ?? 0,
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
          parameters: signature.$1,
          optional: signature.$2,
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
    );
    _skipMember();
    return true;
  }

  void _value(Set<String> modifiers) {
    if (i >= tokens.length) return;
    final raw = _rawType();
    if (!isIdent) {
      _skipMember();
      return;
    }
    final at = _here;
    final name = take();
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
        parameters: signature.$1,
        optional: signature.$2,
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
      var bound = 'num';
      if (peek == 'extends') {
        i++;
        bound = _simplify(_rawType(), map);
      }
      map[name] = bound;
      if (peek == ',') i++;
    }
    if (peek == '>') i++;
    return map;
  }

  (List<(String, String)>, int) _parameters(
    Map<String, String> params,
    Map<String, String> fields,
  ) {
    if (peek != '(') return (const [], 0);
    i++;
    final list = <(String, String)>[];
    var optional = 0;
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
      if (peek == 'this') {
        i++;
        if (peek == '.') i++;
        name = isIdent ? take() : '';
        type = fields[name] ?? 'dynamic';
      } else {
        type = _simplify(_rawType(), params);
        name = isIdent ? take() : '';
      }
      if (peek == '=') _skipDefault();
      if (name.isNotEmpty && !name.startsWith('_')) {
        list.add((name, type));
        if (bracket > 0 || (brace > 0 && !required)) optional++;
      }
      if (i == before) i++;
    }
    if (peek == ')') i++;
    return (list, optional);
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
      return 'dynamic';
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
      if (peek == '<') _group('<', '>');
      if (peek == '(') _group('(', ')');
      if (peek == '?') i++;
      return 'dynamic';
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
    final replaced = params.isEmpty
        ? raw
        : raw.replaceAllMapped(RegExp(r'[A-Za-z_][A-Za-z0-9_]*'), (match) {
            return params[match.group(0)!] ?? match.group(0)!;
          });
    final parsed =
        RegExp(r'^([A-Za-z_][A-Za-z0-9_.]*)(<.*>)?(\?)?$').firstMatch(replaced);
    if (parsed == null) return replaced;
    final name = parsed.group(1)!;
    final args = parsed.group(2);
    final nullable = parsed.group(3) ?? '';
    final head = name.contains('.') ? name.split('.').last : name;
    if (args != null && classes.containsKey(head)) return '$head$nullable';
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
      'mixin'
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
        take();
        continue;
      }
      if (!words.contains(peek)) break;
      found.add(take());
    }
    return found;
  }

  bool _introducesType() {
    var k = i + 1;
    const skip = {
      'abstract',
      'base',
      'interface',
      'sealed',
      'mixin',
      'final',
    };
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
      final text = tokens[i++].text;
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
