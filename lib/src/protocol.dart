import 'dart:convert';
import 'dart:io';

import 'compiler.dart';
import 'navigate.dart';

/// One LSP or DAP message with a `Content-Length` header.
String encodeFrame(Object? message) {
  final body = jsonEncode(message);
  final length = utf8.encode(body).length;
  return 'Content-Length: $length\r\n\r\n$body';
}

/// Answers `initialize`, `textDocument/definition`, and `textDocument/rename`.
Map<String, dynamic>? respondLsp(Map message) {
  final request = message.map((key, value) => MapEntry(key.toString(), value));
  final method = request['method'];
  final id = request['id'];
  if (method == 'initialize') {
    return _result(id, {
      'capabilities': {
        'definitionProvider': true,
        'renameProvider': true,
      }
    });
  }
  if (method == 'initialized' || method == 'exit') return null;
  if (method == 'shutdown') return _result(id, null);
  if (method == 'textDocument/definition') {
    return _result(id, _definition(_params(request)));
  }
  if (method == 'textDocument/rename') {
    return _result(id, _rename(_params(request)));
  }
  if (id == null) return null;
  return _error(id, -32601, 'Method not found');
}

/// Answers `initialize` and `setBreakpoints`. A verified breakpoint is the
/// `.quds` statement on that line. This adapter does not launch a process.
Map<String, dynamic>? respondDebug(Map message) {
  final request = message.map((key, value) => MapEntry(key.toString(), value));
  final method = request['method'];
  final id = request['id'];
  if (method == 'initialize') {
    return _result(id, {'supportsConfigurationDoneRequest': false});
  }
  if (method == 'setBreakpoints') {
    return _result(id, _breakpoints(_params(request)));
  }
  if (method == 'disconnect' || method == 'terminate') {
    return id == null ? null : _result(id, null);
  }
  if (id == null) return null;
  return _error(id, -32601, 'Method not found');
}

Map<String, dynamic> _definition(Map<String, dynamic> params) {
  final located = _open(params);
  if (located == null) return const {};
  final position = _map(params['position']);
  final line = (position['line'] as num?)?.toInt() ?? 0;
  final character = (position['character'] as num?)?.toInt() ?? 0;
  final span = definitionAt(located.$1, line + 1, character + 1);
  if (span == null) return const {};
  return {
    'uri': located.$2,
    'range': {
      'start': {'line': span.line - 1, 'character': span.column - 1},
      'end': {
        'line': span.line - 1,
        'character': span.column - 1 + span.length
      },
    }
  };
}

Map<String, dynamic> _rename(Map<String, dynamic> params) {
  final located = _open(params);
  final next = params['newName'];
  if (located == null || next is! String) return const {'changes': {}};
  final position = _map(params['position']);
  final line = (position['line'] as num?)?.toInt() ?? 0;
  final character = (position['character'] as num?)?.toInt() ?? 0;
  final source = located.$3;
  final renamed = renameAt(located.$1, source, line + 1, character + 1, next);
  final rows = source.split('\n');
  final last = rows.isEmpty ? 0 : rows.length - 1;
  return {
    'changes': {
      located.$2: [
        {
          'range': {
            'start': {'line': 0, 'character': 0},
            'end': {
              'line': last,
              'character': rows.isEmpty ? 0 : rows.last.length
            },
          },
          'newText': renamed,
        }
      ]
    }
  };
}

Map<String, dynamic> _breakpoints(Map<String, dynamic> params) {
  final source = _map(params['source']);
  final path = source['path'];
  if (path is! String || !File(path).existsSync()) {
    return {'breakpoints': const []};
  }
  final text = File(path).readAsStringSync();
  final compiled = compile(text, file: path);
  final requested = params['breakpoints'];
  final verified = <Map<String, Object?>>[];
  if (requested is List) {
    for (final item in requested) {
      final breakpoint = _map(item);
      final line = (breakpoint['line'] as num?)?.toInt();
      if (line == null) {
        verified.add({'verified': false});
        continue;
      }
      final column = (breakpoint['column'] as num?)?.toInt();
      final span = column == null
          ? breakpointOnLine(compiled, line)
          : breakpointAt(compiled, line, column);
      verified.add({
        'verified': span != null,
        'line': span?.line ?? line,
        'column': span?.column,
      });
    }
  }
  return {'breakpoints': verified};
}

(Compilation, String, String)? _open(Map<String, dynamic> params) {
  final document = _map(params['textDocument']);
  final uri = document['uri'];
  if (uri is! String) return null;
  final path = Uri.parse(uri).toFilePath();
  final file = File(path);
  if (!file.existsSync()) return null;
  final text = file.readAsStringSync();
  return (compile(text, file: path), uri, text);
}

Map<String, dynamic> _params(Map<String, dynamic> message) =>
    _map(message['params']);

Map<String, dynamic> _map(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _result(Object? id, Object? result) => {
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };

Map<String, dynamic> _error(Object? id, int code, String message) => {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
