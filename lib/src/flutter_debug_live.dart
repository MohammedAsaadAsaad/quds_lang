import 'dart:async';

/// Save/rebuild controller for Flutter's DAP hotReload/hotRestart requests.
/// It never writes machine-protocol messages into the DAP stream.
class FlutterDebugLive {
  FlutterDebugLive(
      {required this.snapshot,
      required this.build,
      required this.refreshMaps,
      required this.send,
      required this.output,
      required this.buildError,
      required String initialSnapshot,
      this.interval = const Duration(milliseconds: 250)})
      : _observed = initialSnapshot {
    _timer = Timer.periodic(interval, (_) => _poll());
  }
  final String Function() snapshot;
  final bool Function() build;
  final void Function() refreshMaps;
  final void Function(Map<String, dynamic>) send;
  final void Function(String) output;
  final String? Function() buildError;
  final Duration interval;
  late final Timer _timer;
  String _observed;
  String? _candidate;
  bool _ready = false, _dirty = false, _closed = false;
  int? _pending;
  bool _internal = false;
  static int _nextInternal = -1;
  final _manual = <Map<String, dynamic>>[];

  bool request(Map<String, dynamic> message) {
    if (!{'hotReload', 'hotRestart', 'restart'}.contains(message['command']))
      return false;
    _manual.add(message);
    _drain();
    return true;
  }

  /// False means an internal proxy response must not reach the editor.
  bool adapterMessage(Map<String, dynamic> message) {
    if (message['type'] == 'event' &&
        message['event'] == 'flutter.appStarted') {
      _ready = true;
      _drain();
    }
    if (message['type'] == 'event' &&
        {'terminated', 'exited'}.contains(message['event'])) dispose();
    if (message['type'] != 'response' ||
        _pending == null ||
        message['request_seq'] != _pending) return true;
    final hidden = _internal;
    _pending = null;
    if (message['success'] == false)
      output(
          'Flutter rejected the update: ${message['message'] ?? 'restart may be required'}');
    _drain();
    return !hidden;
  }

  void _poll() {
    if (_closed) return;
    try {
      final current = snapshot();
      if (current != _observed) {
        if (_candidate == current) {
          _observed = current;
          _candidate = null;
          _dirty = true;
          _drain();
        } else {
          _candidate = current;
        }
      } else {
        _candidate = null;
        _drain();
      }
    } catch (error) {
      output('Cannot inspect Quds sources: $error');
    }
  }

  void _drain() {
    if (_closed || !_ready || _pending != null || (!_dirty && _manual.isEmpty))
      return;
    final request = _manual.isEmpty ? null : _manual.removeAt(0);
    _dirty = false;
    try {
      final before = snapshot();
      if (!build()) {
        final error = buildError() ??
            'Quds compilation failed; running application kept.';
        output(error);
        if (request != null) _failure(request, error);
        return;
      }
      final after = snapshot();
      if (before != after) {
        _dirty = true;
        if (request != null) _manual.insert(0, request);
        return;
      }
      _observed = after;
      _candidate = null;
      refreshMaps();
      _internal = request == null;
      _pending = request?['seq'] as int? ?? _nextInternal--;
      send(request ??
          {
            'seq': _pending,
            'type': 'request',
            'command': 'hotReload',
            'arguments': {'reason': 'Quds source saved'}
          });
    } catch (error) {
      _pending = null;
      output('Quds update failed: $error');
      if (request != null) _failure(request, '$error');
    }
  }

  void _failure(Map<String, dynamic> request, String message) => send({
        'seq': 0,
        'type': 'response',
        'request_seq': request['seq'],
        'command': request['command'],
        'success': false,
        'message': message,
      });

  void dispose() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    for (final request in _manual) {
      _failure(request, 'Debug session ended before the update');
    }
    _manual.clear();
  }
}
