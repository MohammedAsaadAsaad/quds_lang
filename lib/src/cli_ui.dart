import 'dart:async';
import 'dart:io';

/// Parsed global verbosity flags plus the remaining command arguments.
class CliArgs {
  /// Creates a parsed CLI argument bundle.
  const CliArgs({
    required this.arguments,
    required this.verbose,
    required this.quiet,
  });

  /// Arguments remaining after extracting global verbosity flags.
  final List<String> arguments;

  /// Whether detailed progress and diagnostic trace output was requested.
  final bool verbose;

  /// Whether transient progress output should be suppressed.
  final bool quiet;
}

/// Commands whose trailing arguments are forwarded verbatim to another tool
/// or stdio protocol and must not have global Quds flags stripped after them.
const _rawPassthroughCommands = {
  'dart',
  'flutter',
  'pub',
  'devtools',
  'info',
  'lsp',
  'debug',
  'doc-preview',
};

/// Extracts global `--verbose` (`-V`, or `-v` after a Quds command) and
/// `--quiet` (`-q`) flags while preserving `quds -v` as `--version`,
/// preserving everything after `--`, and never consuming user program flags
/// after a `.quds` entry point in `quds run`.
CliArgs extractGlobalCliFlags(List<String> rawArguments,
    {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  var verbose = env['QUDS_VERBOSE'] == '1';
  var quiet = env['QUDS_QUIET'] == '1';
  if (rawArguments.isEmpty) {
    return CliArgs(arguments: const [], verbose: verbose, quiet: quiet);
  }
  final out = <String>[];
  String? command;
  var stopParsing = false;
  var seenRunEntry = false;
  for (var i = 0; i < rawArguments.length; i++) {
    final arg = rawArguments[i];
    if (stopParsing) {
      out.add(arg);
      continue;
    }
    if (arg == '--') {
      stopParsing = true;
      out.add(arg);
      continue;
    }
    // Keep `quds -v` as `--version`.
    if (command == null && out.isEmpty && arg == '-v') {
      out.add(arg);
      stopParsing = true;
      continue;
    }
    final isVerboseFlag =
        arg == '--verbose' || arg == '-V' || (command != null && arg == '-v');
    final isQuietFlag = arg == '--quiet' || arg == '-q';
    if (isVerboseFlag) {
      verbose = true;
      continue;
    }
    if (isQuietFlag) {
      quiet = true;
      continue;
    }
    if (command == null && !arg.startsWith('-')) {
      command = arg;
      out.add(arg);
      if (_rawPassthroughCommands.contains(command) ||
          command.endsWith('.quds')) {
        stopParsing = true;
      }
      continue;
    }
    out.add(arg);
    if (command == 'run' && !seenRunEntry && arg.endsWith('.quds')) {
      seenRunEntry = true;
      stopParsing = true;
    }
  }
  if (verbose) quiet = false;
  return CliArgs(arguments: out, verbose: verbose, quiet: quiet);
}

/// Coordinates clean, responsive CLI formatting, live progress spinners,
/// and on-demand verbose tracing on `stderr` without polluting `stdout`.
class CliUi {
  /// Creates a CLI UI controller.
  CliUi({
    required this.verbose,
    required this.quiet,
    required this.interactive,
    required this.color,
    IOSink? err,
  }) : _err = err ?? stderr;

  /// Detects terminal capabilities from the active environment.
  factory CliUi.detect({
    bool verbose = false,
    bool quiet = false,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final ttyOverride = env['QUDS_CLI_TTY'];
    bool hasTerminal;
    if (ttyOverride == '1') {
      hasTerminal = true;
    } else if (ttyOverride == '0') {
      hasTerminal = false;
    } else {
      try {
        hasTerminal = stderr.hasTerminal;
      } catch (_) {
        hasTerminal = false;
      }
    }
    bool ansi;
    if (env.containsKey('NO_COLOR') || env['TERM'] == 'dumb') {
      ansi = false;
    } else if (ttyOverride == '1') {
      ansi = false;
    } else {
      try {
        ansi = hasTerminal && stderr.supportsAnsiEscapes;
      } catch (_) {
        ansi = false;
      }
    }
    return CliUi(
      verbose: verbose,
      quiet: quiet && !verbose,
      interactive: hasTerminal,
      color: ansi,
    );
  }

  /// Active process-wide UI controller used by the CLI entry point.
  static CliUi current = CliUi.detect();

  /// Whether detailed trace output is enabled (`--verbose` / `-V`).
  final bool verbose;

  /// Whether transient progress output is suppressed (`--quiet` / `-q`).
  final bool quiet;

  /// Whether `stderr` is attached to an interactive terminal.
  final bool interactive;

  /// Whether ANSI color and escape sequences are safe to emit.
  final bool color;

  final IOSink _err;
  var _lastTransientLength = 0;

  /// Whether live minimal status updates should be displayed.
  bool get showsProgress => !quiet && (interactive || verbose);

  /// Formats [elapsed] into a compact human-readable duration.
  String formatDuration(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  /// Wraps [text] in bold ANSI styling when color output is enabled.
  String bold(String text) => color ? '\x1b[1m$text\x1b[0m' : text;

  /// Wraps [text] in dim ANSI styling when color output is enabled.
  String dim(String text) => color ? '\x1b[2m$text\x1b[0m' : text;

  /// Wraps [text] in cyan ANSI styling when color output is enabled.
  String cyan(String text) => color ? '\x1b[36m$text\x1b[0m' : text;

  /// Wraps [text] in green ANSI styling when color output is enabled.
  String green(String text) => color ? '\x1b[32m$text\x1b[0m' : text;

  /// Wraps [text] in yellow ANSI styling when color output is enabled.
  String yellow(String text) => color ? '\x1b[33m$text\x1b[0m' : text;

  /// Wraps [text] in red ANSI styling when color output is enabled.
  String red(String text) => color ? '\x1b[31m$text\x1b[0m' : text;

  /// Formats a `[ok]` / `[note]` / `[missing]` status line with subtle color
  /// when running on an interactive ANSI terminal, preserving plain text
  /// markers for scripts and tests.
  String formatStatusLine(String line) {
    if (!color) return line;
    if (line.startsWith('[ok]')) {
      return '${green('[ok]')}${line.substring(4)}';
    }
    if (line.startsWith('[note]')) {
      return '${yellow('[note]')}${line.substring(6)}';
    }
    if (line.startsWith('[missing]')) {
      return '${red('[missing]')}${line.substring(9)}';
    }
    return line;
  }

  /// Writes a detailed diagnostic line to `stderr` only when `--verbose` is set.
  void detail(String message) {
    if (!verbose) return;
    clearProgress();
    _err.writeln('${cyan('[quds]')} $message');
  }

  /// Writes a brief persistent status line to `stderr` when progress is active.
  void status(String message) {
    if (!showsProgress) return;
    clearProgress();
    _err.writeln('${cyan('[quds]')} $message');
  }

  /// Writes a completed milestone line to `stderr` when progress is active.
  void done(String message, {Duration? elapsed}) {
    if (!showsProgress) return;
    clearProgress();
    final timing =
        elapsed == null ? '' : ' ${dim('(${formatDuration(elapsed)})')}';
    final mark = color ? green('✓') : '[ok]';
    _err.writeln('$mark $message$timing');
  }

  /// Shows a numbered progress step (`[current/total] label`) on `stderr`.
  void step(int current, int total, String label) {
    if (!showsProgress) return;
    final prefix = '[$current/$total]';
    if (verbose) {
      clearProgress();
      _err.writeln('${cyan('[quds]')} $prefix $label');
      return;
    }
    if (interactive) {
      _writeTransient('${cyan(prefix)} $label');
    }
  }

  /// Runs a synchronous [action] while showing an immediate minimal status line
  /// so the terminal never appears frozen during compilation or analysis.
  T phase<T>(
    String label,
    T Function() action, {
    String? doneLabel,
    bool persist = false,
  }) {
    if (!showsProgress) return action();
    final watch = Stopwatch()..start();
    if (verbose) {
      clearProgress();
      _err.writeln('${cyan('[quds]')} $label...');
    } else if (interactive) {
      _writeTransient('${cyan('...')} $label...');
    }
    try {
      final value = action();
      watch.stop();
      clearProgress();
      if (verbose) {
        _err.writeln(
            '${cyan('[quds]')} ${doneLabel ?? label} ${dim('(${formatDuration(watch.elapsed)})')}');
      } else if (persist) {
        done(doneLabel ?? label, elapsed: watch.elapsed);
      }
      return value;
    } catch (_) {
      clearProgress();
      rethrow;
    }
  }

  /// Runs an asynchronous [action] with a live animated spinner and elapsed
  /// timer on interactive terminals (or timestamped start/end lines in
  /// `--verbose` mode).
  Future<T> spin<T>(
    String label,
    Future<T> Function() action, {
    String? doneLabel,
    bool persist = false,
  }) async {
    if (!showsProgress) return action();
    final watch = Stopwatch()..start();
    if (verbose) {
      clearProgress();
      _err.writeln('${cyan('[quds]')} $label...');
      try {
        final value = await action();
        watch.stop();
        _err.writeln(
            '${cyan('[quds]')} ${doneLabel ?? label} ${dim('(${formatDuration(watch.elapsed)})')}');
        return value;
      } catch (_) {
        watch.stop();
        _err.writeln(
            '${red('[quds]')} Failed: $label ${dim('(${formatDuration(watch.elapsed)})')}');
        rethrow;
      }
    }
    const ansiFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    const asciiFrames = ['|', '/', '-', r'\'];
    final frames = color ? ansiFrames : asciiFrames;
    var index = 0;
    void render() {
      final frame = frames[index++ % frames.length];
      final seconds = (watch.elapsedMilliseconds / 1000).toStringAsFixed(1);
      final line = '${cyan(frame)} $label ${dim('(${seconds}s)')}';
      _writeTransient(line);
    }

    render();
    final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      render();
    });
    try {
      final value = await action();
      watch.stop();
      timer.cancel();
      clearProgress();
      if (persist) {
        done(doneLabel ?? label, elapsed: watch.elapsed);
      }
      return value;
    } catch (_) {
      timer.cancel();
      clearProgress();
      rethrow;
    }
  }

  /// Clears any active single-line transient progress indicator on `stderr`.
  void clearProgress() {
    if (_lastTransientLength == 0) return;
    if (color) {
      _err.write('\r\x1b[2K');
    } else {
      _err.write('\r${' ' * _lastTransientLength}\r');
    }
    _lastTransientLength = 0;
  }

  void _writeTransient(String text) {
    final visibleLength = _stripAnsi(text).length;
    if (color) {
      _err.write('\r\x1b[2K$text');
    } else {
      final pad = visibleLength < _lastTransientLength
          ? ' ' * (_lastTransientLength - visibleLength)
          : '';
      _err.write('\r$text$pad');
    }
    _lastTransientLength = visibleLength;
  }

  static final _ansiPattern = RegExp(r'\x1b\[[0-9;]*m');
  static String _stripAnsi(String text) => text.replaceAll(_ansiPattern, '');
}
