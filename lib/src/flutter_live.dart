import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Bridges saved Quds sources to Flutter's documented machine protocol.
/// Compilation is provided by the CLI; no Flutter-specific syntax is involved.
class FlutterLiveSession {
  FlutterLiveSession(
      {required this.process,
      required this.snapshot,
      required this.build,
      this.initialSnapshot,
      this.input,
      this.pollInterval = const Duration(milliseconds: 250),
      void Function(String)? log})
      : log = log ?? ((message) => stdout.writeln(message));

  final Process process;
  final String Function() snapshot;
  final bool Function() build;
  final String? initialSnapshot;
  final Stream<List<int>>? input;
  final Duration pollInterval;
  final void Function(String) log;
  String? _appId;
  bool _ready = false, _closed = false, _busy = false;
  bool _queued = false, _fullRestart = false;
  String _observed = '';
  String? _candidate;
  int _nextId = 1;
  int? _restartId;
  Timer? _timer;

  void _send(String method, Map<String, Object?> params, {int? id}) {
    if (_closed) return;
    process.stdin.writeln(jsonEncode([
      {'id': id ?? _nextId++, 'method': method, 'params': params}
    ]));
  }

  void _request(bool fullRestart) {
    _queued = true;
    _fullRestart = _fullRestart || fullRestart;
    _drain();
  }

  void _drain() {
    if (_closed || !_ready || _appId == null || _busy || !_queued) return;
    final restart = _fullRestart;
    _queued = false;
    _fullRestart = false;
    _busy = true;
    try {
      log(restart
          ? 'Quds: recompiling before hot restart...'
          : 'Quds: source changed, recompiling...');
      final before = snapshot();
      if (!build()) {
        log('Quds: compilation failed; running app kept. Save a correction to retry.');
        _busy = false;
        return;
      }
      // A save during compilation must be compiled before requesting a reload.
      final after = snapshot();
      if (before != after) {
        _busy = false;
        _queued = true;
        _fullRestart = restart;
        return;
      }
      _observed = after;
      _candidate = null;
      _restartId = _nextId++;
      _send(
          'app.restart',
          {
            'appId': _appId,
            'fullRestart': restart,
            'pause': false,
            'reason': restart ? 'Quds hot restart' : 'Quds source saved'
          },
          id: _restartId);
      log(restart
          ? 'Quds: hot restart requested.'
          : 'Quds: hot reload requested.');
    } catch (error) {
      _busy = false;
      log('Quds: update failed: $error');
    }
  }

  void _message(Map message) {
    if (message['id'] == _restartId && _restartId != null) {
      _restartId = null;
      _busy = false;
      final result = message['result'];
      if (message['error'] != null ||
          (result is Map && result['code'] != null && result['code'] != 0)) {
        log('Quds: Flutter rejected the update: ${message['error'] ?? result}. Use R for hot restart.');
      } else {
        log('Quds: Flutter update completed.');
      }
      _drain();
      return;
    }
    final params = message['params'];
    if (params is! Map) return;
    switch (message['event']) {
      case 'app.start':
        _appId = params['appId'] as String?;
        final device = params['deviceId'];
        final mode = params['mode'];
        final details = [
          if (device != null && '$device'.isNotEmpty) 'on $device',
          if (mode != null && '$mode'.isNotEmpty) '($mode)',
        ].join(' ');
        log(details.isEmpty
            ? 'Flutter: starting app...'
            : 'Flutter: starting app $details...');
      case 'app.started':
        _ready = true;
        log('Flutter: app running.');
        _drain();
      case 'app.log':
        final text = params['log'];
        if (text != null && '$text'.isNotEmpty) log('$text');
      case 'daemon.logMessage':
        final text = params['message'];
        if (text != null && '$text'.isNotEmpty) log('$text');
      case 'app.progress':
        final text = params['message'];
        final finished = params['finished'] == true;
        if (text != null && '$text'.isNotEmpty) {
          log(finished ? 'Flutter: $text done.' : 'Flutter: $text');
        }
      case 'app.webLaunchUrl':
        final url = params['url'];
        if (url != null && '$url'.isNotEmpty) {
          log('Flutter: web app available at $url');
        }
      case 'app.debugPort':
        final uri = params['wsUri'];
        if (uri != null && '$uri'.isNotEmpty) {
          log('Flutter: VM service available at $uri');
        }
      case 'app.stop':
        _ready = false;
        log('Flutter: app stopped.');
    }
  }

  Future<int> run() async {
    // Flutter may close its input pipe while it is exiting.
    unawaited(process.stdin.done.catchError((Object _) {}));
    _observed = initialSnapshot ?? snapshot();
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is List) {
          for (final message in decoded) {
            if (message is Map) _message(message);
          }
          return;
        }
      } on FormatException {/* Ordinary Flutter tool output is not JSON. */}
      log(line);
    });
    final errors = process.stderr.transform(utf8.decoder).listen(stderr.write);
    final keys = input?.listen((bytes) {
      for (final byte in bytes) {
        if (byte == 114 || byte == 82) _request(byte == 82);
        if (byte == 113 || byte == 3) {
          if (_appId != null) {
            _send('app.stop', {'appId': _appId});
          } else {
            process.kill();
          }
        }
        if (byte == 104) {
          log('Quds: save = hot reload; r = reload; R = restart; q = quit.');
        }
      }
    });
    _timer = Timer.periodic(pollInterval, (_) {
      if (_closed) return;
      try {
        final current = snapshot();
        if (current != _observed) {
          // Two identical polls debounce editor save bursts and atomic replaces.
          if (current == _candidate) {
            _observed = current;
            _candidate = null;
            _request(false);
          } else {
            _candidate = current;
          }
        } else {
          _candidate = null;
          _drain();
        }
      } catch (error) {
        log('Quds: cannot inspect sources: $error');
      }
    });
    log('Quds: watching saved sources. r: reload, R: restart, q: quit.');
    try {
      return await process.exitCode;
    } finally {
      _closed = true;
      _timer?.cancel();
      await keys?.cancel();
      await output.cancel();
      await errors.cancel();
    }
  }
}
