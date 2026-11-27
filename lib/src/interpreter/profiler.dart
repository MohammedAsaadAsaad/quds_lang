/// Pure-Dart execution profiler and hierarchical call-tree tracer for the
/// embedded Quds interpreter (`QudsProfiler`, `QudsLineProfile`, `QudsCallNode`).
///
/// Tracks per-line hit counts, execution hotspots, and full recursive call trees
/// (e.g. `fib(5) -> fib(4), fib(3)` with arguments, return values, and duration).
/// Zero `dart:io` or Flutter dependencies.
library;

import '../source.dart';
import 'values.dart';

/// Per-line execution profile entry.
class QudsLineProfile {
  QudsLineProfile({
    required this.file,
    required this.line,
    this.hits = 0,
    this.totalMicros = 0,
  });

  final String file;
  final int line;
  int hits;
  int totalMicros;

  Map<String, Object?> toJson() => {
        'file': file,
        'line': line,
        'hits': hits,
        'totalMicros': totalMicros,
      };
}

/// One node in the hierarchical function call tree captured by [QudsProfiler].
class QudsCallNode {
  QudsCallNode({
    required this.name,
    required this.argsSummary,
    required this.depth,
    required this.line,
    required this.startMicros,
  });

  final String name;
  final String argsSummary;
  final int depth;
  final int line;
  final int startMicros;
  String returnSummary = '';
  int durationMicros = 0;
  final List<QudsCallNode> children = [];

  Map<String, Object?> toJson() => {
        'name': name,
        'args': argsSummary,
        'return': returnSummary,
        'depth': depth,
        'line': line,
        'durationMicros': durationMicros,
        'children': [for (final c in children) c.toJson()],
      };
}

/// Attachable execution profiler & call-tree recorder for [QudsSession].
class QudsProfiler {
  QudsProfiler({
    this.enabled = true,
    this.maxCallNodes = 4000,
  });

  bool enabled;
  final int maxCallNodes;

  final Map<String, QudsLineProfile> _lines = {};
  final List<QudsCallNode> _roots = [];
  final List<QudsCallNode> _activeStack = [];
  final Stopwatch _clock = Stopwatch();
  int _lastStatementMicros = 0;
  int _totalCallNodes = 0;

  /// All profiled source lines.
  List<QudsLineProfile> get lineProfiles => List.unmodifiable(_lines.values);

  /// Top-level call tree roots recorded during the last run.
  List<QudsCallNode> get callTrees => List.unmodifiable(_roots);

  /// Total number of recorded function calls.
  int get totalCalls => _totalCallNodes;

  /// Returns the hottest source lines sorted by hit count (and time) descending.
  List<QudsLineProfile> hotspots({int top = 10}) {
    final list = List<QudsLineProfile>.from(_lines.values);
    list.sort((a, b) {
      final byHits = b.hits.compareTo(a.hits);
      if (byHits != 0) return byHits;
      return b.totalMicros.compareTo(a.totalMicros);
    });
    return list.take(top).toList(growable: false);
  }

  /// Clears previous run data and starts the internal stopwatch.
  void resetForRun() {
    _lines.clear();
    _roots.clear();
    _activeStack.clear();
    _totalCallNodes = 0;
    _clock
      ..reset()
      ..start();
    _lastStatementMicros = 0;
  }

  /// Records execution of a statement at [span].
  void recordStatement(SourceSpan span) {
    if (!enabled) return;
    final now = _clock.elapsedMicroseconds;
    final delta = now - _lastStatementMicros;
    _lastStatementMicros = now;
    final key = '${span.file}:${span.line}';
    final entry = _lines.putIfAbsent(
      key,
      () => QudsLineProfile(file: span.file, line: span.line),
    );
    entry.hits++;
    if (delta > 0) entry.totalMicros += delta;
  }

  /// Called when entering a user-defined function call.
  QudsCallNode? enterCall(
    String name,
    List<Object?> positional,
    Map<String, Object?> named,
    SourceSpan span,
  ) {
    if (!enabled || _totalCallNodes >= maxCallNodes) return null;
    _totalCallNodes++;
    final parts = <String>[
      for (final p in positional) qudsSummarizeValue(p, maxLength: 24),
      for (final e in named.entries)
        '${e.key}: ${qudsSummarizeValue(e.value, maxLength: 20)}',
    ];
    final node = QudsCallNode(
      name: name,
      argsSummary: parts.join(', '),
      depth: _activeStack.length,
      line: span.line,
      startMicros: _clock.elapsedMicroseconds,
    );
    if (_activeStack.isEmpty) {
      _roots.add(node);
    } else {
      _activeStack.last.children.add(node);
    }
    _activeStack.add(node);
    return node;
  }

  /// Called when exiting a user-defined function call.
  void exitCall(QudsCallNode? node, Object? returnValue) {
    if (node == null) return;
    node.durationMicros = _clock.elapsedMicroseconds - node.startMicros;
    node.returnSummary = qudsSummarizeValue(returnValue, maxLength: 32);
    if (_activeStack.isNotEmpty && identical(_activeStack.last, node)) {
      _activeStack.removeLast();
    } else {
      _activeStack.remove(node);
    }
  }

  Map<String, Object?> toJson() => {
        'totalCalls': _totalCallNodes,
        'hotspots': [for (final h in hotspots(top: 15)) h.toJson()],
        'callTrees': [for (final r in _roots) r.toJson()],
      };
}
