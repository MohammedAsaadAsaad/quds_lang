import 'dart:convert';
import 'dart:io';

import 'compiler.dart';
import 'complete.dart';
import 'format.dart';
import 'lexer.dart';
import 'navigate.dart';
import 'parser.dart';

/// One LSP or DAP message with a `Content-Length` header.
String encodeFrame(Object? message) {
  final body = jsonEncode(message);
  final length = utf8.encode(body).length;
  return 'Content-Length: $length\r\n\r\n$body';
}

/// The response to one message, plus notifications to send after it.
class LspExchange {
  const LspExchange([this.response, this.notifications = const []]);
  final Map<String, dynamic>? response;
  final List<Map<String, dynamic>> notifications;
}

/// One language-server session. Open buffers win over the files on disk.
class LspSession {
  final _documents = <String, _OpenDocument>{};

  LspExchange handle(Map message) {
    final request =
        message.map((key, value) => MapEntry(key.toString(), value));
    final method = request['method'];
    final id = request['id'];
    try {
      return _handle(request, method, id);
    } on CompilerException catch (error) {
      if (id == null) return const LspExchange();
      return LspExchange(_error(id, -32603, error.message));
    } on ArgumentError catch (error) {
      if (id == null) return const LspExchange();
      return LspExchange(_error(id, -32602, '${error.message}'));
    }
  }

  LspExchange _handle(
      Map<String, dynamic> request, Object? method, Object? id) {
    if (method == 'initialize') {
      return LspExchange(_result(id, {
        'capabilities': {
          'textDocumentSync': 1,
          'definitionProvider': true,
          'hoverProvider': true,
          'completionProvider': {
            'triggerCharacters': ['.'],
            'resolveProvider': false,
          },
          'codeLensProvider': {'resolveProvider': false},
          'semanticTokensProvider': {
            'legend': {
              'tokenTypes': semanticTokenTypes,
              'tokenModifiers': semanticTokenModifiers,
            },
            'full': true,
          },
          'renameProvider': true,
          'documentFormattingProvider': true,
        }
      }));
    }
    if (method == 'initialized' || method == 'exit') return const LspExchange();
    if (method == 'shutdown') return LspExchange(_result(id, null));
    if (method == 'textDocument/didOpen') {
      return _didOpen(_params(request));
    }
    if (method == 'textDocument/didChange') {
      return _didChange(_params(request));
    }
    if (method == 'textDocument/didClose') {
      return _didClose(_params(request));
    }
    if (method == 'textDocument/definition') {
      return LspExchange(_result(id, _definition(_params(request))));
    }
    if (method == 'textDocument/hover') {
      return LspExchange(_result(id, _hover(_params(request))));
    }
    if (method == 'textDocument/completion') {
      return LspExchange(_result(id, _completion(_params(request))));
    }
    if (method == 'textDocument/codeLens') {
      return LspExchange(_result(id, _codeLenses(_params(request))));
    }
    if (method == 'textDocument/semanticTokens/full') {
      return LspExchange(_result(id, _semanticTokens(_params(request))));
    }
    if (method == 'textDocument/rename') {
      return LspExchange(_result(id, _rename(_params(request))));
    }
    if (method == 'textDocument/formatting') {
      return _format(id, _params(request));
    }
    if (id == null) return const LspExchange();
    return LspExchange(_error(id, -32601, 'Method not found'));
  }

  LspExchange _didOpen(Map<String, dynamic> params) {
    final document = _map(params['textDocument']);
    final uri = document['uri'];
    final text = document['text'];
    if (uri is! String || text is! String) return const LspExchange();
    final opened =
        _OpenDocument(uri, (document['version'] as num?)?.toInt() ?? 0, text);
    _documents[uri] = opened;
    return LspExchange(null, [_publish(opened)]);
  }

  LspExchange _didChange(Map<String, dynamic> params) {
    final document = _map(params['textDocument']);
    final uri = document['uri'];
    if (uri is! String) return const LspExchange();
    final opened = _documents[uri];
    if (opened == null) return const LspExchange();
    final version = (document['version'] as num?)?.toInt();
    if (version != null && version < opened.version) return const LspExchange();
    final changes = params['contentChanges'];
    if (changes is List) {
      for (final change in changes) {
        opened.text = _applyChange(opened.text, _map(change));
      }
    }
    if (version != null) opened.version = version;
    return LspExchange(null, [_publish(opened)]);
  }

  LspExchange _didClose(Map<String, dynamic> params) {
    final document = _map(params['textDocument']);
    final uri = document['uri'];
    if (uri is! String) return const LspExchange();
    _documents.remove(uri);
    return LspExchange(null, [
      {
        'jsonrpc': '2.0',
        'method': 'textDocument/publishDiagnostics',
        'params': {'uri': uri, 'diagnostics': const []},
      }
    ]);
  }

  LspExchange _format(Object? id, Map<String, dynamic> params) {
    final opened = _document(params);
    if (opened == null) {
      return LspExchange(_error(id, -32602, 'No open document'));
    }
    try {
      Parser(Lexer().tokenize(opened.text, file: opened.file)).parse();
    } on CompilerException catch (error) {
      return LspExchange(_error(id, -32603, error.message), [_publish(opened)]);
    }
    return LspExchange(
        _result(id, _edits(opened.text, formatQuds(opened.text))));
  }

  Map<String, Object?> _completion(Map<String, dynamic> params) {
    final position = _map(params['position']);
    final line = (position['line'] as num?)?.toInt() ?? 0;
    final character = (position['character'] as num?)?.toInt() ?? 0;
    final opened = _document(params);
    if (opened != null) {
      return {
        'isIncomplete': false,
        'items': completeAt(
          source: opened.text,
          line: line,
          character: character,
          stable: opened.stableFor(line),
          compileSource: opened.analyze,
        ),
      };
    }
    final document = _map(params['textDocument']);
    final uri = document['uri'];
    if (uri is! String) return {'isIncomplete': false, 'items': const []};
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'file') {
      return {'isIncomplete': false, 'items': const []};
    }
    final path = parsed.toFilePath();
    final file = File(path);
    if (!file.existsSync()) return {'isIncomplete': false, 'items': const []};
    final text = file.readAsStringSync();
    return {
      'isIncomplete': false,
      'items': completeAt(
        source: text,
        line: line,
        character: character,
        compileSource: (source) {
          try {
            return compile(source, file: path);
          } on CompilerException {
            return null;
          }
        },
      ),
    };
  }

  Object? _hover(Map<String, dynamic> params) {
    final located = _tryCompile(params);
    if (located == null) return null;
    final position = _map(params['position']);
    final line = (position['line'] as num?)?.toInt() ?? 0;
    final character = (position['character'] as num?)?.toInt() ?? 0;
    final text = hoverAt(located.$1, located.$3, line + 1, character + 1);
    if (text == null) return null;
    return {
      'contents': {'kind': 'plaintext', 'value': text},
    };
  }

  List<Map<String, Object?>> _codeLenses(Map<String, dynamic> params) {
    final located = _tryCompile(params);
    if (located == null) return const [];
    final lenses = <Map<String, Object?>>[];
    for (final span in mainSpans(located.$1, located.$3)) {
      final range = _range(located.$3, span);
      for (final action in const [
        ('Run', 'quds.run'),
        ('Debug', 'quds.debug'),
        ('Profile', 'quds.profile'),
      ]) {
        lenses.add({
          'range': range,
          'command': {
            'title': action.$1,
            'command': action.$2,
            'arguments': [located.$2],
          },
        });
      }
    }
    return lenses;
  }

  Map<String, Object> _semanticTokens(Map<String, dynamic> params) {
    final located = _tryCompile(params);
    if (located == null) return {'data': const []};
    return {'data': semanticTokenData(located.$1, located.$3)};
  }

  Map<String, dynamic> _definition(Map<String, dynamic> params) {
    final located = _compile(params);
    if (located == null) return const {};
    final position = _map(params['position']);
    final line = (position['line'] as num?)?.toInt() ?? 0;
    final character = (position['character'] as num?)?.toInt() ?? 0;
    final span = definitionAt(
      located.$1,
      line + 1,
      character + 1,
      sourceOf: (file) => _textFor(file, located.$2, located.$3),
    );
    if (span == null) return const {};
    final text = _textFor(span.file, located.$2, located.$3);
    return {
      'uri': _uriFor(span.file, located.$2),
      'range': text == null ? _spanRange(span) : _range(text, span),
    };
  }

  String? _textFor(String file, String currentUri, String currentText) {
    if (file == '<input>' || file.isEmpty) return currentText;
    if (_sameFile(_fileOfUri(currentUri), file)) return currentText;
    for (final document in _documents.values) {
      if (_sameFile(document.file, file)) return document.text;
    }
    final handle = File(file);
    if (!handle.existsSync()) return null;
    return handle.readAsStringSync();
  }

  String _uriFor(String file, String currentUri) {
    if (file == '<input>' || file.isEmpty) return currentUri;
    if (_sameFile(_fileOfUri(currentUri), file)) return currentUri;
    for (final document in _documents.values) {
      if (_sameFile(document.file, file)) return document.uri;
    }
    return Uri.file(File(file).absolute.path).toString();
  }

  Map<String, dynamic> _rename(Map<String, dynamic> params) {
    final located = _compile(params);
    final next = params['newName'];
    if (located == null || next is! String) return const {'changes': {}};
    final position = _map(params['position']);
    final line = (position['line'] as num?)?.toInt() ?? 0;
    final character = (position['character'] as num?)?.toInt() ?? 0;
    final source = located.$3;
    final renamed = renameAt(located.$1, source, line + 1, character + 1, next);
    return {
      'changes': {
        located.$2: _edits(source, renamed),
      }
    };
  }

  Map<String, dynamic> _publish(_OpenDocument document) {
    final diagnostics = document.diagnostics().map((error) {
      return {
        'range': _range(document.text, error.span),
        'severity': error.code.startsWith('W') ? 2 : 1,
        'code': error.code,
        'source': 'quds',
        'message': error.message,
      };
    }).toList();
    return {
      'jsonrpc': '2.0',
      'method': 'textDocument/publishDiagnostics',
      'params': {'uri': document.uri, 'diagnostics': diagnostics},
    };
  }

  _OpenDocument? _document(Map<String, dynamic> params) {
    final document = _map(params['textDocument']);
    final uri = document['uri'];
    if (uri is! String) return null;
    return _documents[uri];
  }

  (Compilation, String, String)? _tryCompile(Map<String, dynamic> params) {
    try {
      return _compile(params);
    } on CompilerException {
      return null;
    }
  }

  (Compilation, String, String)? _compile(Map<String, dynamic> params) {
    final opened = _document(params);
    if (opened != null) {
      final compilation = opened.compilation();
      if (compilation == null) return null;
      return (compilation, opened.uri, opened.text);
    }
    final document = _map(params['textDocument']);
    final uri = document['uri'];
    if (uri is! String) return null;
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'file') return null;
    final path = parsed.toFilePath();
    final file = File(path);
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync();
    return (compile(text, file: path), uri, text);
  }
}

class _OpenDocument {
  _OpenDocument(this.uri, this.version, this.text);
  final String uri;
  int version;
  String text;
  String? _readyText;
  Compilation? _compilation;
  Compilation? _good;
  String? _goodText;
  final _recovered = <String, Compilation?>{};
  List<CompilerException> _diagnostics = const [];

  String get file {
    final parsed = Uri.tryParse(uri);
    if (parsed != null && parsed.scheme == 'file') return parsed.toFilePath();
    return '<input>';
  }

  /// One analysis of the current buffer. Hover and tokens reuse it.
  List<CompilerException> diagnostics() {
    _ensure();
    return _diagnostics;
  }

  Compilation? compilation() {
    _ensure();
    return _compilation;
  }

  /// The last successful analysis when every line above [line] is unchanged.
  Compilation? stableFor(int line) {
    _ensure();
    final good = _good;
    final previous = _goodText;
    if (good == null || previous == null) return null;
    if (previous == text || _samePrefix(previous, text, line)) return good;
    return null;
  }

  /// Compiles [source] without replacing the diagnostics of the open buffer.
  Compilation? analyze(String source) {
    if (source == text) {
      final current = compilation();
      if (current != null) return current;
    }
    if (_recovered.containsKey(source)) return _recovered[source];
    Compilation? compiled;
    try {
      compiled = compile(source, file: file);
    } on CompilerException {
      compiled = null;
    }
    if (_recovered.length > 4) _recovered.clear();
    _recovered[source] = compiled;
    return compiled;
  }

  void _ensure() {
    if (_readyText == text) return;
    _recovered.clear();
    _compilation = null;
    try {
      final compiled = compile(text, file: file);
      _compilation = compiled;
      _good = compiled;
      _goodText = text;
      _diagnostics = List<CompilerException>.of(compiled.semantics.warnings);
    } on CompilerException {
      _diagnostics = diagnose(text, file: file);
    }
    _readyText = text;
  }
}

bool _samePrefix(String previous, String current, int line) {
  final end = _lineStart(previous, line);
  if (end != _lineStart(current, line)) return false;
  return previous.substring(0, end) == current.substring(0, end);
}

int _lineStart(String source, int line) {
  var index = 0;
  var current = 0;
  while (index < source.length && current < line) {
    final unit = source.codeUnitAt(index);
    if (unit == 13) {
      index++;
      if (index < source.length && source.codeUnitAt(index) == 10) index++;
      current++;
    } else if (unit == 10) {
      index++;
      current++;
    } else {
      index++;
    }
  }
  return index;
}

/// Answers `initialize`, definition, and rename for one stateless message.
/// A buffer that must survive across messages uses [LspSession].
Map<String, dynamic>? respondLsp(Map message) =>
    LspSession().handle(message).response;

/// Answers `initialize` and `setBreakpoints` for one message.
///
/// A verified breakpoint is the `.quds` statement on that line. The running
/// debugger is `quds debug`, which launches the generated Dart program and
/// maps those lines. This function does not launch a process.
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

List<Map<String, Object?>> _edits(String source, String replacement) {
  if (source == replacement) return const [];
  final rows = source.split('\n');
  final last = rows.isEmpty ? 0 : rows.length - 1;
  return [
    {
      'range': {
        'start': {'line': 0, 'character': 0},
        'end': {
          'line': last,
          'character': rows.isEmpty ? 0 : rows.last.length,
        },
      },
      'newText': replacement,
    }
  ];
}

String _applyChange(String source, Map<String, dynamic> change) {
  final text = change['text'];
  if (text is! String) return source;
  if (!change.containsKey('range')) return text;
  final range = _map(change['range']);
  final start = _map(range['start']);
  final end = _map(range['end']);
  final lines = source.split('\n');
  int offsetOf(int line, int character) {
    var offset = 0;
    final limit = line < lines.length ? line : lines.length;
    for (var i = 0; i < limit; i++) {
      offset += lines[i].length + 1;
    }
    if (line < lines.length) {
      final row = lines[line];
      offset += character < row.length ? character : row.length;
    }
    return offset;
  }

  final startLine = (start['line'] as num?)?.toInt() ?? 0;
  final startChar = (start['character'] as num?)?.toInt() ?? 0;
  final endLine = (end['line'] as num?)?.toInt() ?? startLine;
  final endChar = (end['character'] as num?)?.toInt() ?? startChar;
  final from = offsetOf(startLine, startChar);
  final to = offsetOf(endLine, endChar);
  return source.replaceRange(from, to < from ? from : to, text);
}

bool _sameFile(String? left, String right) {
  if (left == null || left == '<input>' || right == '<input>') return false;
  if (left == right) return true;
  return File(left).absolute.path == File(right).absolute.path;
}

String? _fileOfUri(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed == null || parsed.scheme != 'file') return null;
  return parsed.toFilePath();
}

Map<String, Object> _spanRange(SourceSpan span) {
  final character = span.column < 1 ? 0 : span.column - 1;
  return {
    'start': {'line': span.line - 1, 'character': character},
    'end': {
      'line': span.line - 1,
      'character': character + span.length,
    },
  };
}

Map<String, Object> _range(String source, SourceSpan span) {
  return {
    'start': _position(source, span.offset),
    'end': _position(source, span.offset + span.length),
  };
}

Map<String, int> _position(String source, int byteOffset) {
  final bytes = utf8.encode(source);
  final end = byteOffset < 0
      ? 0
      : (byteOffset > bytes.length ? bytes.length : byteOffset);
  final prefix = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
  final parts = prefix.split('\n');
  return {'line': parts.length - 1, 'character': parts.last.length};
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
