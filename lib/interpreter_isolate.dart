/// Non-blocking Dart `Isolate` worker entrypoint for the embedded Quds
/// interpreter (Dart VM & Flutter Mobile/Desktop).
///
/// Kept separate from `package:quds/interpreter.dart` so the core interpreter
/// remains 100% Web-compatible with zero `dart:isolate` or `dart:io` imports.
library quds.interpreter_isolate;

export 'src/interpreter/isolate_runner.dart'
    show
        QudsIsolateEvent,
        QudsIsolateHandle,
        QudsIsolateResult,
        QudsIsolateRunner;
