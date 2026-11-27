/// Non-blocking Dart `Isolate` worker for executing heavy Quds scripts off the
/// UI thread with live progress/print streaming and instant cancellation.
///
/// Exported via `package:quds/interpreter_isolate.dart` so `package:quds/interpreter.dart`
/// remains 100% Web-compatible with zero `dart:isolate` or `dart:io` imports.
library;

import 'dart:async';
import 'dart:isolate';

import 'outputs.dart';
import 'policy.dart';
import 'session.dart';
import 'values.dart';

/// Live message streamed from a background [QudsIsolateRunner] worker.
class QudsIsolateEvent {
  const QudsIsolateEvent({
    required this.kind,
    this.text,
    this.steps,
  });

  /// `'print'` | `'progress'` | `'error'`
  final String kind;
  final String? text;
  final int? steps;
}

/// JSON-safe result returned across the Dart `Isolate` boundary.
class QudsIsolateResult {
  const QudsIsolateResult({
    required this.succeeded,
    this.valueSummary,
    this.printedLines = const [],
    this.outputsJson = const [],
    this.stepsExecuted = 0,
    this.elapsedMicros = 0,
    this.error,
    this.cancelled = false,
  });

  final bool succeeded;
  final String? valueSummary;
  final List<String> printedLines;
  final List<Map<String, Object?>> outputsJson;
  final int stepsExecuted;
  final int elapsedMicros;
  final String? error;
  final bool cancelled;

  String get stdout => printedLines.join('\n');
  Duration get elapsed => Duration(microseconds: elapsedMicros);
}

/// Running background isolate execution handle with live event stream & instant cancel.
class QudsIsolateHandle {
  QudsIsolateHandle._({
    required this.result,
    required this.events,
    required void Function() onCancel,
  }) : _onCancel = onCancel;

  final Future<QudsIsolateResult> result;
  final Stream<QudsIsolateEvent> events;
  final void Function() _onCancel;

  /// Immediately terminates the worker isolate without waiting for script ticks.
  void cancel() => _onCancel();
}

/// Launches heavy Quds computations in a dedicated Dart [Isolate].
class QudsIsolateRunner {
  const QudsIsolateRunner._();

  /// Starts executing [source] in a background [Isolate].
  static QudsIsolateHandle start(
    String source, {
    String file = '<isolate>',
    int maxSteps = 2000000,
    int timeoutMs = 30000,
    Map<String, Object?> interactiveInputs = const {},
    Set<String>? allowedLibraries,
  }) {
    final eventController = StreamController<QudsIsolateEvent>.broadcast();
    final resultCompleter = Completer<QudsIsolateResult>();
    final receivePort = ReceivePort();
    Isolate? worker;
    var cancelled = false;

    void cleanup() {
      receivePort.close();
      if (!eventController.isClosed) {
        eventController.close();
      }
    }

    receivePort.listen((message) {
      if (message is! Map) return;
      final type = message['type'] as String?;
      if (type == 'print') {
        eventController.add(QudsIsolateEvent(
          kind: 'print',
          text: message['text'] as String?,
        ));
      } else if (type == 'progress') {
        eventController.add(QudsIsolateEvent(
          kind: 'progress',
          steps: (message['steps'] as num?)?.toInt(),
        ));
      } else if (type == 'done') {
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(QudsIsolateResult(
            succeeded: (message['succeeded'] as bool?) ?? false,
            valueSummary: message['valueSummary'] as String?,
            printedLines: [
              for (final s in (message['printedLines'] as List? ?? const []))
                '$s',
            ],
            outputsJson: [
              for (final o in (message['outputsJson'] as List? ?? const []))
                (o as Map).cast<String, Object?>(),
            ],
            stepsExecuted: (message['stepsExecuted'] as num?)?.toInt() ?? 0,
            elapsedMicros: (message['elapsedMicros'] as num?)?.toInt() ?? 0,
            error: message['error'] as String?,
          ));
        }
        cleanup();
      }
    });

    final payload = <String, Object?>{
      'sendPort': receivePort.sendPort,
      'source': source,
      'file': file,
      'maxSteps': maxSteps,
      'timeoutMs': timeoutMs,
      'interactiveInputs': interactiveInputs,
      if (allowedLibraries != null)
        'allowedLibraries': allowedLibraries.toList(),
    };

    Isolate.spawn(_isolateEntry, payload).then((iso) {
      if (cancelled) {
        iso.kill(priority: Isolate.immediate);
      } else {
        worker = iso;
      }
    }).catchError((Object err) {
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(QudsIsolateResult(
          succeeded: false,
          error: '$err',
        ));
      }
      cleanup();
    });

    return QudsIsolateHandle._(
      result: resultCompleter.future,
      events: eventController.stream,
      onCancel: () {
        if (cancelled) return;
        cancelled = true;
        worker?.kill(priority: Isolate.immediate);
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(const QudsIsolateResult(
            succeeded: false,
            cancelled: true,
            error: 'Cancelled by host.',
          ));
        }
        cleanup();
      },
    );
  }

  /// Convenience one-shot helper awaiting the background isolate result.
  static Future<QudsIsolateResult> run(
    String source, {
    String file = '<isolate>',
    int maxSteps = 2000000,
    int timeoutMs = 30000,
    Map<String, Object?> interactiveInputs = const {},
    Set<String>? allowedLibraries,
  }) =>
      start(
        source,
        file: file,
        maxSteps: maxSteps,
        timeoutMs: timeoutMs,
        interactiveInputs: interactiveInputs,
        allowedLibraries: allowedLibraries,
      ).result;
}

Future<void> _isolateEntry(Map<String, Object?> payload) async {
  final sendPort = payload['sendPort']! as SendPort;
  final source = payload['source']! as String;
  final file = payload['file']! as String;
  final maxSteps = payload['maxSteps']! as int;
  final timeoutMs = payload['timeoutMs']! as int;
  final interactiveInputs = (payload['interactiveInputs'] as Map? ?? const {})
      .cast<String, Object?>();
  final rawLibs = payload['allowedLibraries'] as List?;

  final policy = QudsExecutionPolicy.standard(
    maxSteps: maxSteps,
    timeout: Duration(milliseconds: timeoutMs),
    allowedLibraries: rawLibs != null
        ? {for (final l in rawLibs) '$l'}
        : const {
            'quds:math',
            'quds:core',
            'quds:collection',
            'quds:text',
            'quds:json',
            'quds:async',
            'quds:ext',
            'quds:viz',
            'quds:data',
            'dart:math',
            'dart:convert',
          },
  );

  final session = QudsSession(policy: policy);
  final sub = session.events.listen((event) {
    if (event is QudsPrintEvent) {
      sendPort.send({'type': 'print', 'text': event.text});
    } else if (event is QudsStepProgressEvent) {
      sendPort.send({'type': 'progress', 'steps': event.stepsExecuted});
    }
  });

  try {
    final res = await session.run(
      source,
      file: file,
      interactiveInputs: interactiveInputs,
    );
    final outputsJson = <Map<String, Object?>>[
      for (final o in res.outputs)
        if (o is QudsOutput) o.toJson(),
    ];
    sendPort.send({
      'type': 'done',
      'succeeded': res.succeeded,
      'valueSummary': res.value == null ? null : qudsFormatValue(res.value),
      'printedLines': res.printedLines,
      'outputsJson': outputsJson,
      'stepsExecuted': res.stepsExecuted,
      'elapsedMicros': res.elapsed.inMicroseconds,
      if (res.error != null) 'error': '${res.error}',
    });
  } finally {
    await sub.cancel();
    await session.dispose();
  }
}
