import 'dart:io';

import 'sourcemap.dart';

/// Environment for a Flutter desktop process started from the editor.
///
/// A VS Code snap prepends its own data directories and schema directory.
/// On Ubuntu 26.04 GTK then reads a schema that no longer has `antialiasing`
/// and aborts. The app keeps the desktop directories the snap saved, and
/// drops the snap schema directory.
///
/// Pass the result with `includeParentEnvironment: false`. Otherwise Dart
/// keeps the editor value.
Map<String, String> desktopLaunchEnvironment(Map<String, String> source) {
  final environment = Map<String, String>.from(source);
  final schemas = environment['GSETTINGS_SCHEMA_DIR'];
  if (schemas != null && _underSnap(schemas)) {
    environment.remove('GSETTINGS_SCHEMA_DIR');
  }
  final saved = environment['XDG_DATA_DIRS_VSCODE_SNAP_ORIG'];
  if (saved != null && saved.isNotEmpty) {
    environment['XDG_DATA_DIRS'] = saved;
    return environment;
  }
  final data = environment['XDG_DATA_DIRS'];
  if (data == null) return environment;
  final kept = data
      .split(':')
      .where((part) => part.isNotEmpty && !_underSnap(part))
      .join(':');
  if (kept.isEmpty) {
    environment.remove('XDG_DATA_DIRS');
  } else if (kept != data) {
    environment['XDG_DATA_DIRS'] = kept;
  }
  return environment;
}

bool _underSnap(String path) => path.replaceAll('\\', '/').contains('/snap/');

/// The generated Dart file and source map for one `.quds` file.
class DebugBinary {
  const DebugBinary(this.qudsPath, this.dartPath, this.sourceMap, {this.cwd});
  final String qudsPath;
  final String dartPath;
  final String sourceMap;

  /// Working directory for the debug adapter. Flutter uses the package root.
  final String? cwd;
}

/// What the proxy should do with one DAP message from the editor.
class DebugAction {
  DebugAction.forward(this.message) : reply = null;
  DebugAction.reply(Map<String, dynamic> response)
      : message = null,
        reply = response;

  /// The message to send to the Dart debug adapter.
  final Map<String, dynamic>? message;

  /// A response to send to the editor instead of the adapter.
  final Map<String, dynamic>? reply;
}

/// Rewrites Quds breakpoints and stack frames around the Dart debug adapter.
///
/// The adapter debugs the generated Dart file. This translator moves a
/// breakpoint from a `.quds` line to the generated line, and moves a stopped
/// frame back to the `.quds` line.
class DebugTranslator {
  DebugTranslator({this.build});

  /// Compiles [qudsPath]. A null return is a failure described by [fail].
  final DebugBinary? Function(
      String qudsPath, void Function(String message) fail)? build;
  String? buildError;
  final _files = <String, _BoundFile>{};
  final _pending = <int, List<_PlannedBreakpoint>>{};
  final _frameFile = <int, String>{};
  final _frameLine = <int, int>{};
  final _scopeFrame = <int, int>{};
  final _refFile = <int, String>{};
  final _variablesRef = <int, int>{};
  var _sequence = 1;
  var _stopOnEntry = false;

  /// Dart can report the startup pause while resolving pending breakpoints,
  /// followed by a real breakpoint stop before it handles the client's next
  /// request. Exposing that internal entry pause invites a stale continue.
  /// Explicit stopOnEntry requests still expose the entry stop.
  bool shouldPresent(Map<String, dynamic> message) =>
      _stopOnEntry ||
      message['type'] != 'event' ||
      message['event'] != 'stopped' ||
      (message['body'] as Map?)?['reason'] != 'entry';

  void bind(DebugBinary binary) {
    final positions = binary.sourceMap.isEmpty
        ? null
        : SourcePositions.parse(binary.sourceMap);
    _files[_key(binary.qudsPath)] = _BoundFile(
      binary.qudsPath,
      binary.dartPath,
      positions,
      cwd: binary.cwd,
      names: positions?.names ?? const {},
      locals: positions?.locals ?? const [],
    );
  }

  DebugAction accept(Map<String, dynamic> message) {
    if (message['type'] != 'request') return DebugAction.forward(message);
    final command = message['command'];
    if (command == 'launch') return _launch(message);
    if (command == 'setBreakpoints') return _setBreakpoints(message);
    if (command == 'scopes') _rememberScope(message);
    if (command == 'variables') _rememberVariables(message);
    if (command == 'evaluate') return _evaluate(message);
    return DebugAction.forward(message);
  }

  Map<String, dynamic> present(Map<String, dynamic> message) {
    final type = message['type'];
    if (type == 'response' && message['command'] == 'initialize') {
      final body = message['body'];
      if (body is Map) body['supportsEvaluateForHovers'] = true;
    }
    if (type == 'response' && message['command'] == 'setBreakpoints') {
      return _presentBreakpoints(message);
    }
    if (type == 'response' && message['command'] == 'stackTrace') {
      final body = message['body'];
      if (body is Map) _rewriteFrames(body['stackFrames']);
    }
    if (type == 'event' && message['event'] == 'output') {
      final body = message['body'];
      if (body is Map && body['output'] is String) {
        body['output'] = _rewriteText(body['output'] as String);
      }
    }
    if (type == 'response' && message['command'] == 'scopes') {
      _bindScopes(message);
    }
    if (type == 'response' && message['command'] == 'variables') {
      _renameVariables(message);
    }
    if (type == 'event' && message['event'] == 'breakpoint') {
      final body = message['body'];
      if (body is Map) _rewriteBreakpoint(body['breakpoint']);
    }
    if (type == 'event' && message['event'] == 'stopped') {
      final body = message['body'];
      if (body is Map) _rewriteStopped(body);
    }
    return message;
  }

  DebugAction _launch(Map<String, dynamic> message) {
    final arguments = _map(message['arguments']);
    _stopOnEntry = arguments['stopOnEntry'] == true;
    final program = arguments['program'];
    if (program is! String || !program.endsWith('.quds')) {
      return DebugAction.forward(message);
    }
    final binary = _binary(program, required: true);
    if (binary == null) {
      return DebugAction.reply(_failure(
        message,
        buildError ?? 'Quds could not build $program',
      ));
    }
    arguments['program'] = binary.dartPath;
    if (binary.cwd != null) {
      arguments['cwd'] = binary.cwd;
      _selectDevice(arguments);
    } else {
      arguments.putIfAbsent('cwd', () => _directory(binary.qudsPath));
    }
    message['arguments'] = arguments;
    return DebugAction.forward(message);
  }

  DebugAction _setBreakpoints(Map<String, dynamic> message) {
    final arguments = _map(message['arguments']);
    final source = _map(arguments['source']);
    final path = source['path'];
    if (path is! String || !path.endsWith('.quds')) {
      return DebugAction.forward(message);
    }
    final binary = _binary(path, required: false);
    final positions = binary == null ? null : _files[_key(binary.qudsPath)];
    final requested = arguments['breakpoints'];
    final plans = <_PlannedBreakpoint>[];
    final forwarded = <Map<String, Object?>>[];
    if (requested is List) {
      for (final item in requested) {
        final breakpoint = _map(item);
        final line = (breakpoint['line'] as num?)?.toInt();
        if (line == null || positions == null) {
          plans.add(_PlannedBreakpoint(line ?? 1, null));
          continue;
        }
        final generated = positions.positions?.generated(path, line);
        plans.add(_PlannedBreakpoint(line, generated));
        if (generated != null) {
          forwarded.add({'line': generated});
        }
      }
    }
    final id = (message['seq'] as num?)?.toInt();
    if (id != null) _pending[id] = plans;
    if (positions == null) {
      _pending.remove(id);
      return DebugAction.reply(_breakpointsReply(message, plans, const []));
    }
    source['path'] = positions.dartPath;
    source['name'] = _name(positions.dartPath);
    arguments['source'] = source;
    arguments['breakpoints'] = forwarded;
    message['arguments'] = arguments;
    return DebugAction.forward(message);
  }

  Map<String, dynamic> _presentBreakpoints(Map<String, dynamic> message) {
    final id = (message['request_seq'] as num?)?.toInt();
    final plans = id == null ? null : _pending.remove(id);
    if (plans == null) return message;
    final body = _map(message['body']);
    final returned = body['breakpoints'];
    final verified = returned is List ? returned : const [];
    message['body'] = {'breakpoints': _merge(plans, verified)};
    return message;
  }

  List<Map<String, Object?>> _merge(
      List<_PlannedBreakpoint> plans, List returned) {
    final merged = <Map<String, Object?>>[];
    var cursor = 0;
    for (final plan in plans) {
      if (plan.dartLine == null) {
        merged.add({'verified': false, 'line': plan.qudsLine});
        continue;
      }
      final child =
          cursor < returned.length ? _map(returned[cursor]) : const {};
      cursor++;
      merged.add({
        ...child.map((key, value) => MapEntry(key.toString(), value)),
        'verified': child['verified'] == true,
        'line': plan.qudsLine,
      });
    }
    return merged;
  }

  Map<String, dynamic> _breakpointsReply(
    Map<String, dynamic> message,
    List<_PlannedBreakpoint> plans,
    List returned,
  ) {
    return {
      'seq': _sequence++,
      'type': 'response',
      'request_seq': message['seq'],
      'success': true,
      'command': 'setBreakpoints',
      'body': {'breakpoints': _merge(plans, returned)},
    };
  }

  void _rewriteFrames(Object? frames) {
    if (frames is! List) return;
    for (final frame in frames) {
      if (frame is! Map) continue;
      final line = (frame['line'] as num?)?.toInt();
      final source = frame['source'];
      if (line == null || source is! Map) continue;
      final hit = _original(_string(source['path']), line);
      if (hit == null) continue;
      frame['source'] = _moved(source, hit);
      frame['line'] = hit.$2;
      frame['column'] = hit.$3;
      final id = (frame['id'] as num?)?.toInt();
      if (id != null) {
        _frameFile[id] = _key(hit.$1);
        _frameLine[id] = hit.$2;
      }
    }
  }

  void _rememberScope(Map<String, dynamic> message) {
    final id = (message['seq'] as num?)?.toInt();
    final frame = (_map(message['arguments'])['frameId'] as num?)?.toInt();
    if (id != null && frame != null) _scopeFrame[id] = frame;
  }

  void _rememberVariables(Map<String, dynamic> message) {
    final id = (message['seq'] as num?)?.toInt();
    final reference =
        (_map(message['arguments'])['variablesReference'] as num?)?.toInt();
    if (id != null && reference != null) _variablesRef[id] = reference;
  }

  void _bindScopes(Map<String, dynamic> message) {
    final id = (message['request_seq'] as num?)?.toInt();
    final frame = id == null ? null : _scopeFrame.remove(id);
    final file = frame == null ? null : _frameFile[frame];
    if (file == null) return;
    final scopes = _map(message['body'])['scopes'];
    if (scopes is! List) return;
    for (final scope in scopes) {
      if (scope is! Map) continue;
      final reference = (scope['variablesReference'] as num?)?.toInt();
      if (reference != null && reference != 0) _refFile[reference] = file;
    }
  }

  DebugAction _evaluate(Map<String, dynamic> message) {
    final arguments = _map(message['arguments']);
    final expression = arguments['expression'];
    final frame = (arguments['frameId'] as num?)?.toInt();
    final file = frame == null ? null : _frameFile[frame];
    final line = frame == null ? null : _frameLine[frame];
    final locals = file == null ? null : _files[file]?.locals;
    if (expression is! String || line == null || locals == null) {
      return DebugAction.forward(message);
    }
    final rewritten = _debugExpression(expression, locals, line);
    if (rewritten == expression) return DebugAction.forward(message);
    arguments['expression'] = rewritten;
    message['arguments'] = arguments;
    return DebugAction.forward(message);
  }

  void _renameVariables(Map<String, dynamic> message) {
    final id = (message['request_seq'] as num?)?.toInt();
    final reference = id == null ? null : _variablesRef.remove(id);
    final file = reference == null ? null : _refFile[reference];
    final names = file == null ? null : _files[file]?.names;
    if (names == null || names.isEmpty) return;
    final variables = _map(message['body'])['variables'];
    if (variables is! List) return;
    for (final variable in variables) {
      if (variable is! Map) continue;
      final name = variable['name'];
      final source = name is String ? names[name] : null;
      if (source != null) variable['name'] = source;
    }
  }

  void _rewriteBreakpoint(Object? breakpoint) {
    if (breakpoint is! Map) return;
    final line = (breakpoint['line'] as num?)?.toInt();
    final source = breakpoint['source'];
    if (line == null) return;
    final hit = source is Map
        ? _original(_string(source['path']), line)
        : _onlyOriginal(line);
    if (hit == null) return;
    breakpoint['source'] = source is Map
        ? _moved(source, hit)
        : {
            'path': hit.$1,
            'name': _name(hit.$1),
            'sourceReference': 0,
          };
    breakpoint['line'] = hit.$2;
    breakpoint['column'] = hit.$3;
  }

  void _rewriteStopped(Map<dynamic, dynamic> body) {
    for (final key in ['text', 'description']) {
      if (body[key] is String) body[key] = _rewriteText(body[key] as String);
    }
    final line = (body['line'] as num?)?.toInt();
    final source = body['source'];
    if (line == null || source is! Map) return;
    final hit = _original(_string(source['path']), line);
    if (hit == null) return;
    body['source'] = _moved(source, hit);
    body['line'] = hit.$2;
    body['column'] = hit.$3;
  }

  String _rewriteText(String text) {
    var current = text;
    for (final bound in _files.values) {
      final positions = bound.positions;
      if (positions == null) continue;
      current = positions.rewriteStack(current, bound.dartPath);
      final file = File(bound.qudsPath);
      if (file.existsSync()) {
        current = preferQudsSnippet(current, file.readAsStringSync());
      }
    }
    return current;
  }

  Map<String, Object?> _moved(Map source, (String, int, int) hit) {
    return {
      ...source.map((key, value) => MapEntry(key.toString(), value)),
      'path': hit.$1,
      'name': _name(hit.$1),
      'sourceReference': 0,
    };
  }

  (String, int, int)? _onlyOriginal(int line) {
    final hits = <(String, int, int)>[];
    for (final bound in _files.values) {
      final position = bound.positions?.original(line);
      if (position == null) continue;
      hits.add((bound.qudsPath, position.$2, position.$3));
    }
    return hits.length == 1 ? hits.single : null;
  }

  (String, int, int)? _original(String? path, int line) {
    if (path == null) return null;
    final file = _filePath(path);
    for (final bound in _files.values) {
      if (!_paths(bound.dartPath, file)) continue;
      final position = bound.positions?.original(line);
      if (position == null) return null;
      return (bound.qudsPath, position.$2, position.$3);
    }
    return null;
  }

  DebugBinary? _binary(String qudsPath, {required bool required}) {
    final key = _key(qudsPath);
    final existing = _files[key];
    if (existing != null) {
      return DebugBinary(
        existing.qudsPath,
        existing.dartPath,
        '',
        cwd: existing.cwd,
      );
    }
    String? failed;
    final built = build?.call(qudsPath, (message) => failed = message);
    if (built == null) {
      if (required) {
        buildError = failed ?? 'Quds could not build $qudsPath';
      }
      return null;
    }
    bind(
        DebugBinary(qudsPath, built.dartPath, built.sourceMap, cwd: built.cwd));
    final bound = _files[_key(qudsPath)]!;
    return DebugBinary(bound.qudsPath, bound.dartPath, built.sourceMap,
        cwd: bound.cwd);
  }

  Map<String, dynamic> _failure(Map<String, dynamic> message, String error) {
    return {
      'seq': _sequence++,
      'type': 'response',
      'request_seq': message['seq'],
      'success': false,
      'command': message['command'],
      'message': error,
    };
  }

  static String _key(String path) => _filePath(path);

  static String _filePath(String value) {
    if (value.startsWith('file:')) return Uri.parse(value).toFilePath();
    return value;
  }

  static void _selectDevice(Map<String, dynamic> arguments) {
    final device = arguments['deviceId'];
    if (device is String && device.isNotEmpty) {
      final current = arguments['toolArgs'];
      final args = current is List ? [...current] : <Object?>[];
      if (!args.contains('-d') && !args.contains('--device-id')) {
        args.addAll(['-d', device]);
        arguments['toolArgs'] = args;
      }
    }
    final env = arguments['env'];
    if (env is Map) {
      arguments['env'] = desktopLaunchEnvironment(env.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ));
    }
  }

  static String _directory(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(0, slash);
  }

  static String _name(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  static String? _string(Object? value) => value is String ? value : null;

  static bool _paths(String left, String right) =>
      left == right || left.endsWith('/$right') || right.endsWith('/$left');
}

class _BoundFile {
  _BoundFile(this.qudsPath, this.dartPath, this.positions,
      {this.cwd, this.names = const {}, this.locals = const []});
  final String qudsPath;
  final String dartPath;
  final SourcePositions? positions;
  final String? cwd;
  final Map<String, String> names;
  final List<QudsLocal> locals;
}

/// Rewrites source names in [expression] to the generated names in scope at
/// [line]. Text inside quotes stays as written.
String _debugExpression(String expression, List<QudsLocal> locals, int line) {
  final out = StringBuffer();
  var index = 0;
  while (index < expression.length) {
    final unit = expression.codeUnitAt(index);
    if (unit == 34 || unit == 39) {
      final quote = expression[index];
      final triple = expression.startsWith(quote * 3, index);
      final width = triple ? 3 : 1;
      var cursor = index + width;
      while (cursor < expression.length) {
        if (expression[cursor] == '\\') {
          cursor += cursor + 1 < expression.length ? 2 : 1;
          continue;
        }
        if (expression.startsWith(quote * width, cursor)) {
          cursor += width;
          break;
        }
        cursor++;
      }
      out.write(expression.substring(index, cursor));
      index = cursor;
      continue;
    }
    if (_identStart(unit)) {
      final start = index;
      index++;
      while (index < expression.length &&
          _identPart(expression.codeUnitAt(index))) {
        index++;
      }
      final name = expression.substring(start, index);
      out.write(_dartInScope(locals, name, line) ?? name);
      continue;
    }
    out.writeCharCode(unit);
    index++;
  }
  return out.toString();
}

bool _identStart(int unit) =>
    unit == 95 || (unit >= 65 && unit <= 90) || (unit >= 97 && unit <= 122);

bool _identPart(int unit) => _identStart(unit) || (unit >= 48 && unit <= 57);

String? _dartInScope(List<QudsLocal> locals, String name, int line) {
  QudsLocal? best;
  for (final local in locals) {
    if (local.name != name || line < local.line || line > local.end) continue;
    if (best == null ||
        local.line > best.line ||
        (local.line == best.line && local.end < best.end)) {
      best = local;
    }
  }
  return best?.dartName;
}

class _PlannedBreakpoint {
  _PlannedBreakpoint(this.qudsLine, this.dartLine);
  final int qudsLine;
  final int? dartLine;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}
