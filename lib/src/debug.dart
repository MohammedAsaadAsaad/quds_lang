import 'sourcemap.dart';

/// The generated Dart file and source map for one `.quds` file.
class DebugBinary {
  const DebugBinary(this.qudsPath, this.dartPath, this.sourceMap);
  final String qudsPath;
  final String dartPath;
  final String sourceMap;
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
  var _sequence = 1;

  void bind(DebugBinary binary) {
    final positions = binary.sourceMap.isEmpty
        ? null
        : SourcePositions.parse(binary.sourceMap);
    _files[_key(binary.qudsPath)] = _BoundFile(
      binary.qudsPath,
      binary.dartPath,
      positions,
    );
  }

  DebugAction accept(Map<String, dynamic> message) {
    if (message['type'] != 'request') return DebugAction.forward(message);
    final command = message['command'];
    if (command == 'launch') return _launch(message);
    if (command == 'setBreakpoints') return _setBreakpoints(message);
    return DebugAction.forward(message);
  }

  Map<String, dynamic> present(Map<String, dynamic> message) {
    final type = message['type'];
    if (type == 'response' && message['command'] == 'setBreakpoints') {
      return _presentBreakpoints(message);
    }
    if (type == 'response' && message['command'] == 'stackTrace') {
      final body = message['body'];
      if (body is Map) _rewriteFrames(body['stackFrames']);
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
    arguments.putIfAbsent('cwd', () => _directory(binary.qudsPath));
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
    final line = (body['line'] as num?)?.toInt();
    final source = body['source'];
    if (line == null || source is! Map) return;
    final hit = _original(_string(source['path']), line);
    if (hit == null) return;
    body['source'] = _moved(source, hit);
    body['line'] = hit.$2;
    body['column'] = hit.$3;
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
    bind(DebugBinary(qudsPath, built.dartPath, built.sourceMap));
    final bound = _files[_key(qudsPath)]!;
    return DebugBinary(bound.qudsPath, bound.dartPath, built.sourceMap);
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
  _BoundFile(this.qudsPath, this.dartPath, this.positions);
  final String qudsPath;
  final String dartPath;
  final SourcePositions? positions;
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
