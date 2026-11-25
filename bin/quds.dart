import 'package:quds/src/toolchain_update.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:yaml_edit/yaml_edit.dart';

import 'package:quds/quds.dart';
import 'package:quds/src/flutter_project.dart';
import 'package:quds/src/flutter_live.dart';
import 'package:quds/src/flutter_debug_live.dart';
import 'package:quds/src/libraries.dart'
    show libraryTarget, resolveLibraryPath, packageUsesFlutter, packageFileInfo;
import 'package:quds/src/walk.dart';
import 'package:quds/src/sdk.dart';
import 'package:quds/src/toolchain.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _usage();
    return;
  }
  final first = arguments.first;
  if (first == '--version' || first == '-v' || first == 'version') {
    await _version(arguments);
    return;
  }
  if (first.endsWith('.quds') && !first.startsWith('-')) {
    await _run(['run', ...arguments]);
    return;
  }
  const qudsHelpCommands = {
    'build',
    'compile',
    'analyze',
    'test',
    'format',
    'fix',
    'create',
    'doc',
    'migrate',
    'benchmark',
    'doctor',
    'install',
    'lsp',
    'debug',
  };
  if (qudsHelpCommands.contains(first) &&
      first != 'compile' &&
      _hasHelpFlag(arguments.skip(1))) {
    _help(['help', first]);
    return;
  }
  switch (first) {
    case 'build':
      if (arguments.length > 1 &&
          const {
            'apk',
            'appbundle',
            'web',
            'linux',
            'windows',
            'macos',
            'ios',
            'ipa',
            'bundle'
          }.contains(arguments[1])) {
        await _run(['run', ...arguments.skip(2)], buildTarget: arguments[1]);
      } else {
        _build(arguments);
      }
    case 'compile':
      await _compile(arguments);
    case 'run':
      await _run(arguments);
    case 'analyze':
      _analyze(arguments);
    case 'test':
      _test(arguments);
    case 'format':
      _format(arguments);
    case 'fix':
      _fix(arguments);
    case 'create':
      await _create(arguments);
    case 'doc-preview':
      await _docPreviewService();
    case 'flutter':
      await _flutterCommand(arguments.skip(1).toList());
    case 'dart':
      await _dartCommand(arguments.skip(1).toList());
    case 'devtools':
      await _devtools(arguments.skip(1).toList());
    case 'info':
      await _info(arguments.skip(1).toList());
    case 'pub':
      await _pubCommand(arguments.skip(1).toList());
    case 'add':
    case 'remove':
    case 'get':
    case 'upgrade':
    case 'outdated':
    case 'deps':
    case 'publish':
      await _pub(first, arguments);
    case 'doc':
      _doc(arguments);
    case 'migrate':
      await _migrate(arguments);
    case 'benchmark':
      _benchmark(arguments);
    case 'help':
    case '--help':
    case '-h':
      _help(arguments);
    case 'doctor':
      await _doctor(arguments);
    case 'install':
      await _install(arguments);
    case 'lsp':
      final session = LspSession()..background = true;
      _serve(session);
    case 'debug':
      await _debug(arguments);
    default:
      _usage();
  }
}

bool _hasHelpFlag(Iterable<String> args) {
  for (final arg in args) {
    if (arg == '--') return false;
    if (arg == '-h' || arg == '--help') return true;
  }
  return false;
}

Future<void> _version(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: quds --version');
    exitCode = 64;
    return;
  }
  final root = await _compilerRoot();
  final version = root == null ? '' : _pubspecVersion(root);
  final dartVersion = Platform.version.split(' ').first;
  stdout.writeln(version.isEmpty
      ? 'Quds CLI (Dart $dartVersion)'
      : 'Quds CLI $version (Dart $dartVersion)');
}

Future<void> _dartCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: quds dart <arguments>');
    exitCode = 64;
    return;
  }
  final child = await Process.start(_dartExecutable(), arguments,
      mode: ProcessStartMode.inheritStdio);
  exitCode = await child.exitCode;
}

Future<void> _devtools(List<String> arguments) async {
  final child = await Process.start(
      _dartExecutable(), ['devtools', ...arguments],
      mode: ProcessStartMode.inheritStdio);
  exitCode = await child.exitCode;
}

Future<void> _info(List<String> arguments) async {
  final root = await _compilerRoot();
  final version = root == null ? '' : _pubspecVersion(root);
  if (version.isNotEmpty && !_hasHelpFlag(arguments)) {
    stdout.writeln('Quds CLI $version');
  }
  final child = await Process.start(_dartExecutable(), ['info', ...arguments],
      mode: ProcessStartMode.inheritStdio);
  exitCode = await child.exitCode;
}

/// Prints process output with generated `.dart` frames rewritten to `.quds`.
void _writeQuds(
    Object? outText, Object? errText, String? sourceMap, String generatedName) {
  stdout.write(_atQuds(outText, sourceMap, generatedName));
  stderr.write(_atQuds(errText, sourceMap, generatedName));
}

String _atQuds(Object? text, String? sourceMap, String generatedName,
    {String? qudsSource}) {
  final value = text is String ? text : '';
  if (sourceMap == null || value.isEmpty) return value;
  final decoded = jsonDecode(sourceMap);
  if (decoded is! Map) return value;
  final data = Map<String, Object?>.from(decoded);
  data['file'] = generatedName;
  final mapped = mapStack(value, jsonEncode(data));
  if (qudsSource == null) return mapped;
  return preferQudsSnippet(mapped, qudsSource);
}

void _usage() {
  stderr.writeln('Usage: quds <command> ...');
  stderr.writeln('Run `quds help` for the command list.');
  exitCode = 64;
}

void _help(List<String> arguments) {
  if ((arguments.first == 'help' && arguments.length > 2) ||
      (arguments.first != 'help' && arguments.length != 1)) {
    stderr.writeln('Usage: quds help [command]');
    exitCode = 64;
    return;
  }
  final topic =
      arguments.first == 'help' && arguments.length == 2 ? arguments[1] : null;
  final text = _helpText(topic);
  if (text == null) {
    stderr.writeln('Unknown command: $topic');
    stderr.writeln('Run `quds help` for the command list.');
    exitCode = 64;
    return;
  }
  stdout.write(text);
}

String? _helpText(String? topic) {
  const entries = <String, String>{
    'build': 'quds build [--watch] <input.quds>\n'
        '    Compile to Dart under .dart_tool/quds/out/ (defaults to lib/main.quds or main.quds). --watch rebuilds when a source changes.\n'
        'quds build --package [dir]\n'
        '    Compile all lib/**/*.quds files to lib/**/*.dart beside sources for Quds and Dart/Flutter publishing.\n'
        'quds build <apk|appbundle|web|linux|windows|macos|ios|ipa|bundle> [Quds target and Flutter options]\n'
        '    Build a Flutter application from lib/main.quds or an explicit .quds target.\n',
    'compile': 'quds compile <exe|aot-snapshot|jit-snapshot|kernel|js|wasm> [options] <input.quds>\n'
        '    Compile a Quds program to a native binary, snapshot, JavaScript, or WebAssembly via Dart.\n'
        '    Forwards Dart compile options (-o/--output, -D/--define, -O0..-O4, --target-os, --target-arch, etc.).\n',
    'run': 'quds run [vm-options] [input.quds] [arguments] [-e <code>] [-d device] [--debug|--profile|--release] [flutter arguments]\n'
        '    Run the program (or evaluate a Quds snippet with -e/--eval). Supports Dart VM options (--enable-asserts, -D/--define, --observe, --verbosity) and Flutter hot reload.\n',
    'analyze':
        'quds analyze [--fatal-infos] [--[no-]fatal-warnings] [file.quds|dir ...]\n'
            '    Compile and run dart analyze on Quds file(s) or directory (defaults to the current directory).\n',
    'test': 'quds test [file.quds|dir ...] [-n/--name <regex>] [-N/--plain-name <text>] [--fail-fast] [--[no-]enable-asserts] [-r/--reporter <compact|expanded>]\n'
        '    Run Quds test declarations (defaults to test/ when no target is given).\n',
    'format':
        'quds format [file.quds|dir ...] [--check|--set-exit-if-changed] [-o/--output <write|show|none>] [--stdout] [--indent N] [-l/--width/--line-length N] [--no-single-line-if]\n'
            '    Format Quds source files in place (defaults to the current directory).\n',
    'fix': 'quds fix [--dry-run|-n|--apply] [file.quds|dir ...]\n'
        '    Preview (--dry-run, default) or apply (--apply) safe automated fixes (missing shadow/var/(), unused use imports).\n',
    'create': 'quds create --f <name>\n'
        '    Create a Flutter app whose program is lib/main.quds (aliases: -f, --flutter, -t flutter).\n'
        'quds create . [--platforms=linux,android,web] [flutter create arguments]\n'
        '    Add Flutter platform support in the current project, preserving Quds sources.\n'
        'quds create [-t/--template <console|cli|package|flutter>] [--force] [--[no-]pub] <name>\n'
        '    Create a new Quds project or publishable Quds package.\n',
    'pub':
        'quds pub [arguments]\n    Forward all pub commands (add, remove, get, upgrade, outdated, deps, publish, ...) to Dart, or Flutter in a Flutter project.\n',
    'add':
        'quds add <package>\n    Forward to native pub add (Flutter in Flutter projects).\n',
    'remove':
        'quds remove <package>\n    Forward to native pub remove (Flutter in Flutter projects).\n',
    'get':
        'quds get\n    Forward to native pub get (Flutter in Flutter projects).\n',
    'upgrade': 'quds upgrade [arguments]\n    Forward to native pub upgrade.\n',
    'outdated':
        'quds outdated [arguments]\n    Forward to native pub outdated.\n',
    'deps': 'quds deps [arguments]\n    Forward to native pub deps.\n',
    'publish': 'quds publish [arguments]\n    Forward to native pub publish.\n',
    'doc': 'quds doc [-o/--output <path>] <input.quds|dir>\n'
        '    Print /// documentation (or write HTML with -o <out.html|dir>).\n'
        'quds doc test <input.quds>\n'
        '    Check documentation examples.\n'
        'quds doc html <input.quds> <output.html>\n'
        '    Write the documentation as HTML.\n',
    'migrate': 'quds migrate [project-dir] [--check|--dry-run] [--yes|-y] [--keep-dart]\n'
        '    Inspect a Dart or Flutter project for Quds compatibility, back up lib/ under .quds_backup/, ask confirmation, and migrate lib/**/*.dart to .quds.\n'
        'quds migrate <quds.yaml>\n'
        '    Write language: 1.2 to a quds.yaml file. A file pinned to another version is left unchanged.\n',
    'benchmark':
        'quds benchmark <input.quds> [--baseline <microseconds>] [--measure] [--warmup <count>] [--repeat <count>]\n'
            '    Check debug/release output; --measure separates Quds compilation, Dart AOT compilation and AOT process execution including startup.\n',
    'lsp': 'quds lsp\n'
        '    Serve the language protocol on standard input and output.\n',
    'debug': 'quds debug <input.quds>\n'
        '    Proxy the debug adapter. A Flutter package uses flutter debug-adapter.\n',
    'help': 'quds help [command]\n'
        '    Show every command, or the usage of one command.\n',
    'version': 'quds --version\n'
        '    Print the Quds CLI and Dart SDK versions.\n',
    'doctor': 'quds doctor\n'
        '    Check Dart, the quds command, Flutter, and the editors on this machine.\n',
    'info': 'quds info [arguments]\n'
        '    Show Quds and Dart diagnostic tooling information.\n',
    'devtools': 'quds devtools [arguments]\n'
        '    Launch Dart DevTools.\n',
    'dart': 'quds dart <arguments>\n'
        '    Forward any Dart CLI command with its normal arguments.\n',
    'flutter': 'quds flutter <arguments>\n'
        '    Forward Flutter commands, including clean, with their normal arguments.\n',
    'install': 'quds install [--no-update]\n'
        '    Fast-forward the compiler from origin/main, then activate Quds and install editor support.\n'
        '    --no-update skips the repository update and installs the current checkout.\n',
  };
  if (topic == null) {
    final buffer = StringBuffer('Quds commands\n\n');
    for (final entry in entries.values) {
      buffer.writeln(entry.trimRight());
      buffer.writeln();
    }
    return buffer.toString();
  }
  return entries[topic];
}

void _reportCompilerError(CompilerException error, {String? source}) {
  stderr.writeln(formatRichDiagnostic(error, source: source));
}

void _fix(List<String> arguments) {
  var apply = false;
  var dryRun = false;
  final targets = <String>[];
  for (var i = 1; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--apply') {
      apply = true;
    } else if (arg == '--dry-run' || arg == '-n') {
      dryRun = true;
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for quds fix: $arg');
      stderr.writeln(
          'Usage: quds fix [--dry-run|-n|--apply] [file.quds|dir ...]');
      exitCode = 64;
      return;
    } else {
      targets.add(arg);
    }
  }
  if (apply && dryRun) {
    stderr.writeln('Cannot combine --dry-run and --apply.');
    exitCode = 64;
    return;
  }
  final effectiveTargets = targets.isEmpty ? const ['.'] : targets;
  final files = <File>[];
  void collectDir(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.') || name == 'build' || name == 'quds_gen') {
        continue;
      }
      if (entity is Directory) {
        collectDir(entity);
      } else if (entity is File && name.endsWith('.quds')) {
        files.add(entity);
      }
    }
  }

  for (final target in effectiveTargets) {
    final dir = Directory(target);
    final file = File(target);
    if (dir.existsSync()) {
      collectDir(dir);
    } else if (file.existsSync()) {
      files.add(file);
    } else {
      stderr.writeln('Path not found: $target');
      exitCode = 64;
      return;
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stdout.writeln('No .quds files found.');
    return;
  }

  var totalFixes = 0;
  var changedFiles = 0;
  for (final file in files) {
    final source = file.readAsStringSync();
    final result = fixQudsSource(source, file: file.path);
    if (!result.changed) continue;
    changedFiles++;
    totalFixes += result.fixes.length;
    for (final fix in result.fixes) {
      stdout.writeln(
          '${file.path}:${fix.line}: [${fix.code}] ${fix.description}');
    }
    if (apply) {
      file.writeAsStringSync(result.source);
    }
  }

  if (totalFixes == 0) {
    stdout.writeln('Nothing to fix!');
  } else if (apply) {
    stdout.writeln(
        'Applied $totalFixes fix${totalFixes == 1 ? '' : 'es'} in $changedFiles file${changedFiles == 1 ? '' : 's'}.');
  } else {
    stdout.writeln(
        '$totalFixes proposed fix${totalFixes == 1 ? '' : 'es'} in $changedFiles file${changedFiles == 1 ? '' : 's'}. Run with --apply to write changes.');
  }
}

Future<void> _doctor(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: quds doctor');
    exitCode = 64;
    return;
  }
  final root = await _compilerRoot();
  final version = root == null ? '' : _pubspecVersion(root);
  stdout.writeln(version.isEmpty ? 'Quds CLI' : 'Quds CLI $version');
  final lines = <String>[_dartCheck()];
  final quds = commandOnPath('quds');
  if (quds == null) {
    lines.add(
        '[note] quds is not on PATH. Add ${pubBin(homeDirectory())} to PATH.');
  } else {
    lines.add('[ok] quds ($quds)');
  }
  final flutter = commandOnPath('flutter');
  lines.add(flutter == null
      ? '[note] Flutter was not found. Flutter apps need Flutter.'
      : _flutterLine(flutter));
  lines.addAll(editorReport());
  for (final line in lines) {
    stdout.writeln(line);
  }
  if (lines.any((line) => line.startsWith('[missing]'))) exitCode = 1;
}

/// Package config of this `quds` tool, so generated tests can import matcher.
String? _packageConfigPath() {
  var directory = File.fromUri(Platform.script).parent;
  for (var hop = 0; hop < 8; hop++) {
    final candidate = File(
        '${directory.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}package_config.json');
    if (candidate.existsSync()) return candidate.path;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return null;
}

List<String> _withPackages(List<String> args, {File? input}) {
  var config = _packageConfigPath();
  if (input != null) {
    final root = _packageRoot(input.absolute.parent);
    final project = File('${root.path}/.dart_tool/package_config.json');
    if (project.existsSync() && project.path != config) {
      // The program's pub resolution wins. Matcher and other tool helpers are
      // available to temporary Quds test drivers without replacing app packages.
      final packages = <String, Map<String, dynamic>>{};
      for (final file in [if (config != null) File(config), project]) {
        final decoded = jsonDecode(file.readAsStringSync()) as Map;
        for (final raw in decoded['packages'] as List) {
          final entry = Map<String, dynamic>.from(raw as Map);
          entry['rootUri'] =
              file.uri.resolve(entry['rootUri'] as String).toString();
          packages[entry['name'] as String] = entry;
        }
      }
      final output = File('${root.path}/.dart_tool/quds/package_config.json');
      final names = packages.keys.toList()..sort();
      final text = jsonEncode({
        'configVersion': 2,
        'packages': [for (final name in names) packages[name]]
      });
      output.parent.createSync(recursive: true);
      if (!output.existsSync() || output.readAsStringSync() != text) {
        output.writeAsStringSync(text);
      }
      config = output.path;
    }
  }
  if (config == null) return args;
  return ['--packages=$config', ...args];
}

/// The Dart VM. An AOT `quds` binary is not itself the VM.
String _dartExecutable() {
  final resolved = Platform.resolvedExecutable;
  final base = resolved.split(Platform.pathSeparator).last.toLowerCase();
  if (base == 'dart' || base == 'dart.exe') return resolved;
  final found = commandOnPath('dart');
  if (found != null) return found;
  final home = Platform.environment['HOME'];
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (root != null && root.isNotEmpty) '$root/bin/dart',
    if (home != null && home.isNotEmpty) '$home/development/flutter/bin/dart',
    if (home != null && home.isNotEmpty) '$home/flutter/bin/dart',
    '/usr/lib/dart/bin/dart',
    '/usr/bin/dart',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return resolved;
}

String _dartCheck() {
  final executable = _dartExecutable();
  try {
    final reported = Process.runSync(executable, ['--version']);
    final raw = '${reported.stdout}${reported.stderr}';
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(raw);
    if (match == null) {
      return '[missing] Dart version was not recognized ($executable).';
    }
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final supported = major == 3 && (minor > 3 || (minor == 3 && patch >= 0));
    if (!supported) {
      return '[missing] Dart ${match.group(0)} is outside >=3.3.0 <4.0.0.';
    }
    return '[ok] Dart ${match.group(0)} ($executable)';
  } on ProcessException catch (error) {
    return '[missing] Dart did not run: ${error.message}';
  }
}

String _flutterLine(String executable) {
  try {
    final result = Process.runSync(executable, ['--version']);
    final text = '${result.stdout}'.trim();
    final line = (text.isEmpty ? '${result.stderr}' : text).trim();
    final first = line.split('\n').first.trim();
    if (result.exitCode != 0 || first.isEmpty) {
      return '[note] Flutter at $executable did not report a version.';
    }
    return '[ok] $first ($executable)';
  } on ProcessException catch (error) {
    return '[note] Flutter at $executable did not run: ${error.message}';
  }
}

Future<void> _install(List<String> arguments) async {
  if (arguments.length > 2 ||
      arguments.length == 2 && arguments[1] != '--no-update') {
    stderr.writeln('Usage: quds install [--no-update]');
    exitCode = 64;
    return;
  }
  final root = await _compilerRoot();
  if (root == null) {
    stderr.writeln('The quds package root was not found.');
    exitCode = 1;
    return;
  }
  if (!arguments.contains('--no-update')) {
    if (!await updateCompilerCheckout(root, report: stderr.writeln)) {
      exitCode = 1;
      return;
    }
    // Start the updated source, including its extension manifest/file list.
    final dart = _dartExecutable();
    final child = await Process.start(
        dart, ['run', 'bin/quds.dart', 'install', '--no-update'],
        workingDirectory: root.path, mode: ProcessStartMode.inheritStdio);
    exitCode = await child.exitCode;
    return;
  }
  final source = Directory(
      '${root.path}${Platform.pathSeparator}editors${Platform.pathSeparator}vscode');
  for (final name in _extensionFiles) {
    if (!_extensionFile(source, name).existsSync()) {
      stderr.writeln('The editor extension is missing ${name}.');
      exitCode = 1;
      return;
    }
  }
  final package =
      jsonDecode(_extensionFile(source, 'package.json').readAsStringSync());
  if (package is! Map) {
    stderr.writeln('editors/vscode/package.json is not an object.');
    exitCode = 1;
    return;
  }
  final id = '${package['publisher']}.${package['name']}-${package['version']}';
  exitCode = await installToolchain(
    packageRoot: root,
    extensionSource: source,
    extensionId: id,
    extensionFiles: _extensionFiles,
    vsixBytes: () => _vsixBytes(source, package),
  );
}

const _extensionFiles = [
  'package.json',
  'extension.js',
  'language-configuration.json',
  'README.md',
  'syntaxes/quds.tmLanguage.json',
  'icons/quds.png',
];

Future<Directory?> _compilerRoot() async {
  final uri =
      await Isolate.resolvePackageUri(Uri.parse('package:quds/quds.dart'));
  if (uri == null) return null;
  return File.fromUri(uri).parent.parent;
}

String _pubspecVersion(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) return '';
  return RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec.readAsStringSync())
          ?.group(1) ??
      '';
}

File _extensionFile(Directory source, String name) {
  return File([source.path, ...name.split('/')].join(Platform.pathSeparator));
}

List<int> _vsixBytes(Directory source, Map<dynamic, dynamic> package) {
  String xml(Object? value) => '$value'
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final manifest = '''
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="${xml(package['name'])}" Version="${xml(package['version'])}" Publisher="${xml(package['publisher'])}"/>
    <DisplayName>${xml(package['displayName'])}</DisplayName>
    <Description xml:space="preserve">${xml(package['description'])}</Description>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
''';
  const types = '''
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".js" ContentType="application/javascript"/>
  <Default Extension=".md" ContentType="text/markdown"/>
  <Default Extension=".png" ContentType="image/png"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
''';
  final files = <String, List<int>>{
    '[Content_Types].xml': utf8.encode(types),
    'extension.vsixmanifest': utf8.encode(manifest),
    for (final name in _extensionFiles)
      'extension/$name': _extensionFile(source, name).readAsBytesSync(),
  };
  return _storeZip(files);
}

List<int> _storeZip(Map<String, List<int>> files) {
  final local = BytesBuilder();
  final central = BytesBuilder();
  var offset = 0;
  for (final entry in files.entries) {
    final name = utf8.encode(entry.key.replaceAll('\\', '/'));
    final data = entry.value;
    final crc = _crc32(data);
    final header = BytesBuilder();
    _add32(header, 0x04034b50);
    _add16(header, 20);
    _add16(header, 0);
    _add16(header, 0);
    _add16(header, 0);
    _add16(header, 0);
    _add32(header, crc);
    _add32(header, data.length);
    _add32(header, data.length);
    _add16(header, name.length);
    _add16(header, 0);
    header.add(name);
    final headerBytes = header.toBytes();
    local.add(headerBytes);
    local.add(data);
    final directory = BytesBuilder();
    _add32(directory, 0x02014b50);
    _add16(directory, 20);
    _add16(directory, 20);
    _add16(directory, 0);
    _add16(directory, 0);
    _add16(directory, 0);
    _add16(directory, 0);
    _add32(directory, crc);
    _add32(directory, data.length);
    _add32(directory, data.length);
    _add16(directory, name.length);
    _add16(directory, 0);
    _add16(directory, 0);
    _add16(directory, 0);
    _add16(directory, 0);
    _add32(directory, 0);
    _add32(directory, offset);
    directory.add(name);
    central.add(directory.toBytes());
    offset += headerBytes.length + data.length;
  }
  final localBytes = local.toBytes();
  final centralBytes = central.toBytes();
  final end = BytesBuilder();
  _add32(end, 0x06054b50);
  _add16(end, 0);
  _add16(end, 0);
  _add16(end, files.length);
  _add16(end, files.length);
  _add32(end, centralBytes.length);
  _add32(end, localBytes.length);
  _add16(end, 0);
  return [...localBytes, ...centralBytes, ...end.toBytes()];
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final mix = (crc & 1) == 1 ? 0xedb88320 : 0;
      crc = (crc >> 1) ^ mix;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void _add16(BytesBuilder out, int value) {
  out.addByte(value & 0xff);
  out.addByte((value >> 8) & 0xff);
}

void _add32(BytesBuilder out, int value) {
  out.addByte(value & 0xff);
  out.addByte((value >> 8) & 0xff);
  out.addByte((value >> 16) & 0xff);
  out.addByte((value >> 24) & 0xff);
}

const _generatedHeader = '// Generated by Quds MVP-0. Do not edit.\n';
// Bump when previously generated Dart cannot satisfy the current lowering ABI.
const _generatedAbi = 'provider-defaults-v16';
final _watched = <String>{};
final _compiledHash = <String, String>{};

void _build(List<String> arguments) {
  if (arguments.length > 1 && arguments[1] == '--package') {
    if (arguments.length > 3) {
      stderr.writeln('Usage: quds build --package [dir]');
      exitCode = 64;
      return;
    }
    final target = arguments.length == 3 ? arguments[2] : '.';
    _buildPackage(Directory(target));
    return;
  }
  final watch = arguments.length > 1 && arguments[1] == '--watch';
  final rest = watch ? arguments.skip(2).toList() : arguments.skip(1).toList();
  if (rest.length > 1) {
    stderr.writeln(
        'Usage: quds build [--watch] [input.quds] | quds build --package [dir]');
    exitCode = 64;
    return;
  }
  File input;
  if (rest.isEmpty) {
    final root = _packageRoot(Directory.current);
    input = File(
        '${root.path}/${File('${root.path}/lib/main.quds').existsSync() ? 'lib/main.quds' : 'main.quds'}');
    if (!input.existsSync()) {
      stderr.writeln(
          'No lib/main.quds or main.quds found. Specify a .quds entry point.');
      exitCode = 64;
      return;
    }
  } else {
    final path = rest.single;
    if (!path.endsWith('.quds')) {
      stderr.writeln(
          'Usage: quds build [--watch] [input.quds] | quds build --package [dir]');
      exitCode = 64;
      return;
    }
    input = File(path);
  }
  if (!watch) {
    _writeTree(input, <String>{});
    return;
  }
  _watch(input);
}

Future<void> _compile(List<String> arguments) async {
  const targets = {
    'exe',
    'aot-snapshot',
    'jit-snapshot',
    'kernel',
    'js',
    'wasm',
  };
  if (arguments.length < 2 ||
      arguments[1] == '-h' ||
      arguments[1] == '--help') {
    _help(['help', 'compile']);
    return;
  }
  final target = arguments[1];
  if (!targets.contains(target)) {
    stderr.writeln('Unknown compile target: $target');
    stderr.writeln(
        'Supported targets: exe, aot-snapshot, jit-snapshot, kernel, js, wasm');
    exitCode = 64;
    return;
  }
  final rest = arguments.skip(2).toList();
  if (_hasHelpFlag(rest)) {
    final helpProc = await Process.start(
      _dartExecutable(),
      ['compile', target, '--help'],
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await helpProc.exitCode;
    return;
  }
  const valuedFlags = {
    '-o',
    '--output',
    '-D',
    '--define',
    '-p',
    '--packages',
    '-S',
    '--save-debugging-info',
    '--depfile',
    '--target-os',
    '--target-arch',
    '--verbosity',
    '--extra-gen-snapshot-options',
    '--extra-compiler-option',
    '--dump-info',
    '--server-snapshots',
    '-m',
  };
  final flags = <String>[];
  final trainingArgs = <String>[];
  String? entry;
  var hasOutput = false;
  var hasPackages = false;
  for (var i = 0; i < rest.length; i++) {
    final arg = rest[i];
    if (arg == '--') {
      trainingArgs.addAll(rest.skip(i + 1));
      break;
    }
    if (entry != null && target == 'jit-snapshot' && !arg.startsWith('-')) {
      trainingArgs.add(arg);
      continue;
    }
    if (arg == '-o' ||
        arg == '--output' ||
        arg.startsWith('--output=') ||
        (arg.startsWith('-o') && arg.length > 2 && !arg.startsWith('--'))) {
      hasOutput = true;
    }
    if (arg == '-p' || arg == '--packages' || arg.startsWith('--packages=')) {
      hasPackages = true;
    }
    if (valuedFlags.contains(arg)) {
      if (i + 1 >= rest.length) {
        stderr.writeln('Missing value for $arg');
        exitCode = 64;
        return;
      }
      flags.add(arg);
      flags.add(rest[++i]);
    } else if (arg.startsWith('-')) {
      flags.add(arg);
    } else if (entry == null && arg.endsWith('.quds')) {
      entry = arg;
    } else if (target == 'jit-snapshot' && entry != null) {
      trainingArgs.add(arg);
    } else {
      stderr.writeln('Expected a .quds input file, got: $arg');
      exitCode = 64;
      return;
    }
  }
  final root = _packageRoot(Directory.current);
  final input = entry != null
      ? File(entry)
      : File(
          '${root.path}/${File('${root.path}/lib/main.quds').existsSync() ? 'lib/main.quds' : 'main.quds'}');
  if (!input.existsSync()) {
    stderr.writeln(entry == null
        ? 'No lib/main.quds or main.quds found. Specify a .quds entry point.'
        : 'Cannot open file: ${input.path}');
    exitCode = entry == null ? 64 : 74;
    return;
  }
  try {
    final output = _ensureOutput(input);
    if (output == null) return;
    final compileArgs = <String>['compile', target, ...flags];
    if (!hasOutput) {
      final stem = input.path.endsWith('.quds')
          ? input.path.substring(0, input.path.length - 5)
          : input.path;
      final ext = switch (target) {
        'exe' => '.exe',
        'aot-snapshot' => '.aot',
        'jit-snapshot' => '.jit',
        'kernel' => '.dill',
        'js' => '.js',
        'wasm' => '.wasm',
        _ => '',
      };
      compileArgs.addAll(['-o', '$stem$ext']);
    }
    if (!hasPackages && target != 'js' && target != 'wasm') {
      final pkgArgs = _withPackages(const [], input: input);
      compileArgs.addAll(pkgArgs);
    }
    compileArgs.add(output.path);
    compileArgs.addAll(trainingArgs);
    final child = await Process.start(
      _dartExecutable(),
      compileArgs,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await child.exitCode;
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
}

void _buildPackage(Directory target) {
  if (!target.existsSync()) {
    stderr.writeln('Directory not found: ${target.path}');
    exitCode = 64;
    return;
  }
  final root = _packageRoot(target.absolute);
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml found for ${target.path}');
    exitCode = 64;
    return;
  }
  final libDir = Directory('${root.path}/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('No lib/ directory found in ${root.path}');
    exitCode = 64;
    return;
  }
  final sources = <File>[];
  void collect(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.') || name == 'quds_gen' || name == '_quds_sdk') {
        continue;
      }
      if (entity is Directory) {
        collect(entity);
      } else if (entity is File && name.endsWith('.quds')) {
        sources.add(entity);
      }
    }
  }

  collect(libDir);
  sources.sort((a, b) => a.path.compareTo(b.path));
  if (sources.isEmpty) {
    stdout.writeln('No .quds files found under ${libDir.path}');
    return;
  }
  final sdkDir = Directory('${root.path}/lib/src/_quds_sdk');
  for (final input in sources) {
    try {
      final source = input.readAsStringSync();
      var result = compile(source, file: input.path);
      final output =
          File('${input.path.substring(0, input.path.length - 5)}.dart');
      if (result.bundles.isNotEmpty) {
        final runtime = File('${sdkDir.path}/quds_readonly.dart');
        final runtimeUri = _relativeGeneratedUri(output.parent, runtime);
        final directory =
            runtimeUri.substring(0, runtimeUri.lastIndexOf('/') + 1);
        result = relocateGeneratedLibraries(result, directory);
      }
      final existing = output.existsSync() ? output.readAsStringSync() : null;
      if (existing != null && !existing.startsWith(_generatedHeader)) {
        stderr.writeln(
            'Refusing to overwrite non-generated file: ${output.path}');
        exitCode = 73;
        return;
      }
      writeSdkBundles(output.parent.path, result);
      if (existing != null && existing == result.dart) {
        stdout.writeln('Unchanged ${output.path}');
        continue;
      }
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(result.dart);
      stdout.writeln('Built ${output.path}');
    } on CompilerException catch (error) {
      _reportCompilerError(error);
      exitCode = 65;
      return;
    } on FileSystemException catch (error) {
      stderr.writeln(error.message);
      exitCode = 74;
      return;
    }
  }
}

Future<void> _watch(File input) async {
  var stamp = '';
  while (exitCode == 0) {
    if (_watched.isEmpty || _stamp(_watched.toList()) != stamp) {
      _watched.clear();
      _compiledHash.clear();
      if (!_writeTree(input, <String>{})) return;
      // The baseline is the bytes this build read. Re-reading after "Built"
      // would miss a write that landed while that line was still flushing.
      stamp = _baseline();
      await stdout.flush();
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

String _baseline() {
  final ordered = _watched.toList()..sort();
  final buffer = StringBuffer();
  for (final path in ordered) {
    final hash = _compiledHash[path];
    buffer.write(hash == null ? _stamp([path]) : '$path $hash\n');
  }
  return buffer.toString();
}

bool _writeTree(File input, Set<String> seen,
    {bool announce = true,
    bool flutter = false,
    Compilation? initial,
    Directory? projectRoot,
    String? configOrigin}) {
  final path = input.absolute.uri.normalizePath().toFilePath();
  if (!seen.add(path)) return exitCode == 0;
  try {
    final bytes = input.readAsBytesSync();
    _compiledHash[path] = sha256Hex(bytes);
    final ownerRoot = projectRoot ?? _packageRoot(input.absolute.parent);
    final origin = configOrigin ?? path;
    final source = utf8.decode(bytes);
    final result =
        initial ?? compile(source, file: input.path, packageConfigFrom: origin);
    final artifactRoot =
        flutter ? Directory('${ownerRoot.path}/lib/quds_gen') : null;
    final destination = _outputFileForRoot(input, ownerRoot,
        flutter: flutter, configOrigin: origin);
    if (!_emitGenerated(input, result,
        announce: announce,
        destination: destination,
        artifactRoot: artifactRoot,
        projectRoot: ownerRoot,
        configOrigin: origin,
        flutter: flutter,
        sourceText: source)) return false;
    _watched.add(path);
    for (final dependency in result.dependencies) {
      if (!dependency.endsWith('.quds')) continue;
      _watched.add(dependency);
      if (dependency == path) continue;
      if (!_writeTree(File(dependency), seen,
          announce: announce,
          flutter: flutter,
          projectRoot: ownerRoot,
          configOrigin: origin)) return false;
    }
    return exitCode == 0;
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    exitCode = 65;
    return false;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
    return false;
  }
}

Compilation _rewriteTreeImports(File input, Compilation result, File output,
    Directory ownerRoot, String origin, bool flutter, String? sourceText) {
  final inputPath = input.absolute.uri.normalizePath().toFilePath();
  var rewritten = false;
  walkAst(result.program, (node) {
    if (node is! ImportDeclaration || node.uri.startsWith('quds:')) return;
    final target =
        resolveLibraryPath(inputPath, node.uri, packageConfigFrom: origin);
    if (target == null || !File(target).existsSync()) return;
    final needsRewrite = node.uri.startsWith('package:') ||
        node.uri.startsWith('generated:') ||
        !_isUnderDirectory(target, ownerRoot.path) ||
        !_isUnderDirectory(inputPath, ownerRoot.path);
    if (!needsRewrite) return;
    final targetOutput = _outputFileForRoot(File(target), ownerRoot,
        flutter: flutter, configOrigin: origin);
    final relative = _relativeGeneratedUri(output.parent, targetOutput);
    if (result.semantics.resolvedImports[node] != relative) {
      result.semantics.resolvedImports[node] = relative;
      rewritten = true;
    }
  });
  for (final entry in result.semantics.backendTypeImports.entries.toList()) {
    String? target;
    if (entry.value.startsWith('package:')) {
      target =
          resolveLibraryPath(inputPath, entry.value, packageConfigFrom: origin);
    } else {
      final uri = Uri.tryParse(entry.value);
      final dartPath = uri == null
          ? null
          : uri.scheme == 'file'
              ? uri.toFilePath()
              : !uri.hasScheme
                  ? Uri.file(inputPath).resolve(entry.value).toFilePath()
                  : null;
      if (dartPath != null && dartPath.endsWith('.dart')) {
        target = '${dartPath.substring(0, dartPath.length - 5)}.quds';
      }
    }
    if (target == null || !File(target).existsSync()) continue;
    final targetOutput = _outputFileForRoot(File(target), ownerRoot,
        flutter: flutter, configOrigin: origin);
    final relative = _relativeGeneratedUri(output.parent, targetOutput);
    if (entry.value != relative) {
      result.semantics.backendTypeImports[entry.key] = relative;
      rewritten = true;
    }
  }
  if (!rewritten) return result;
  final emitter = DartEmitter(result.semantics);
  final dart = emitter.emit(result.program);
  final source =
      sourceText ?? (input.existsSync() ? input.readAsStringSync() : null);
  return Compilation(result.program, result.semantics, dart,
      sourceMap: source == null
          ? result.sourceMap
          : sourceMapFor(emitter, output.path, input.path,
              program: result.program, source: source),
      dependencies: result.dependencies,
      models: result.models,
      bundles: result.bundles);
}

bool _emitGenerated(File input, Compilation result,
    {bool announce = true,
    File? destination,
    Directory? artifactRoot,
    Directory? projectRoot,
    String? configOrigin,
    bool flutter = false,
    String? sourceText}) {
  final ownerRoot = projectRoot ?? _packageRoot(input.absolute.parent);
  final origin = configOrigin ?? input.absolute.path;
  final output = destination ??
      _outputFileForRoot(input, ownerRoot,
          flutter: flutter, configOrigin: origin);
  result = _rewriteTreeImports(
      input, result, output, ownerRoot, origin, flutter, sourceText);
  final shared =
      artifactRoot ?? Directory('${ownerRoot.path}/.dart_tool/quds/out');
  final runtime = File('${shared.path}/quds_readonly.dart');
  final runtimeUri = _relativeGeneratedUri(output.parent, runtime);
  final directory = runtimeUri.substring(0, runtimeUri.lastIndexOf('/') + 1);
  result = relocateGeneratedLibraries(result, directory);
  final existing = output.existsSync() ? output.readAsStringSync() : null;
  if (existing != null && !existing.startsWith(_generatedHeader)) {
    stderr.writeln('Refusing to overwrite non-generated file: ${output.path}');
    exitCode = 73;
    return false;
  }
  final isLocal = _isUnderDirectory(input.absolute.path, ownerRoot.path);
  if (isLocal) {
    _writeModels(input, result);
  }
  writeSdkBundles(output.parent.path, result);
  final paths = {...result.dependencies, input.absolute.path}.toList()..sort();
  final sources = _digestListed(paths, input);
  final outputDigest = sha256Hex(utf8.encode(result.dart));
  final cache = _cacheFile(input, projectRoot: ownerRoot);
  if (existing != null &&
      existing == result.dart &&
      _cacheFresh(cache, sources, outputDigest)) {
    if (announce) stdout.writeln('Unchanged ${output.path}');
    return true;
  }
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(result.dart);
  if (result.sourceMap != null) {
    File('${output.path}.map').writeAsStringSync(result.sourceMap!);
  }
  cache.parent.createSync(recursive: true);
  cache.writeAsStringSync(jsonEncode({
    'abi': _generatedAbi,
    'sources': sources,
    'output': outputDigest,
    'artifacts': {
      if (result.sourceMap != null)
        '${output.absolute.path}.map':
            sha256Hex(utf8.encode(result.sourceMap!)),
      for (final bundle in result.bundles)
        File('${output.parent.path}/${bundle.fileName}')
            .absolute
            .uri
            .normalizePath()
            .toFilePath(): sha256Hex(utf8.encode(bundle.source)),
    },
    'paths': paths,
    'generated': [for (final model in result.models) model.fileName],
  }));
  if (announce) stdout.writeln('Built ${output.path}');
  return true;
}

bool _isUnderDirectory(String filePath, String directoryPath) {
  final file = _canonicalPathCli(filePath);
  final dir = _canonicalPathCli(directoryPath);
  final prefix = dir.endsWith('/') ? dir : '$dir/';
  return Platform.isWindows
      ? file.toLowerCase().startsWith(prefix.toLowerCase())
      : file.startsWith(prefix);
}

String _canonicalPathCli(String path) {
  final file = File(path);
  if (file.existsSync()) {
    try {
      return file.resolveSymbolicLinksSync().replaceAll('\\', '/');
    } on FileSystemException {/* fall through */}
  }
  final dir = Directory(path);
  if (dir.existsSync()) {
    try {
      return dir.resolveSymbolicLinksSync().replaceAll('\\', '/');
    } on FileSystemException {/* fall through */}
  }
  return File(path)
      .absolute
      .uri
      .normalizePath()
      .toFilePath()
      .replaceAll('\\', '/');
}

/// Generated Dart lives under the package's `.dart_tool/quds/out`, mirroring
/// the source path. A lone file with no package root uses its own directory.
File _outputFile(File input) {
  final root = _packageRoot(input.absolute.parent);
  return _outputFileForRoot(input, root);
}

File _outputFileForRoot(File input, Directory ownerRoot,
    {bool flutter = false, String? configOrigin}) {
  final absolute = input.absolute;
  final sep = Platform.pathSeparator;
  final baseOut = flutter
      ? '${ownerRoot.path}${sep}lib${sep}quds_gen'
      : '${ownerRoot.path}$sep.dart_tool${sep}quds${sep}out';
  if (_isUnderDirectory(absolute.path, ownerRoot.path)) {
    if (flutter) return _flutterGenerated(input, ownerRoot);
    final fileCanon = _canonicalPathCli(absolute.path);
    final rootCanon = _canonicalPathCli(ownerRoot.path);
    final prefix = rootCanon.endsWith('/') ? rootCanon : '$rootCanon/';
    final relative = fileCanon.substring(prefix.length).replaceAll('/', sep);
    final dartName = relative.endsWith('.quds')
        ? '${relative.substring(0, relative.length - 5)}.dart'
        : '$relative.dart';
    return File('$baseOut$sep$dartName');
  }
  final info = packageFileInfo(absolute.path, packageConfigFrom: configOrigin);
  if (info != null) {
    final rel = info.relativeInsideLib.replaceAll('/', sep);
    final dartRel = rel.endsWith('.quds')
        ? '${rel.substring(0, rel.length - 5)}.dart'
        : '$rel.dart';
    return File('$baseOut${sep}_packages$sep${info.name}$sep$dartRel');
  }
  final hash = sha256Hex(utf8.encode(absolute.path)).substring(0, 12);
  final name = absolute.uri.pathSegments.last;
  final dartName = name.endsWith('.quds')
      ? '${name.substring(0, name.length - 5)}.dart'
      : '$name.dart';
  return File('$baseOut${sep}_external$sep$hash$sep$dartName');
}

Directory _packageRoot(Directory start) {
  var current = start;
  while (true) {
    if (File('${current.path}/pubspec.yaml').existsSync() ||
        File('${current.path}/quds.yaml').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) return start;
    current = parent;
  }
}

File _cacheFile(File input, {Directory? projectRoot}) {
  final name = sha256Hex(utf8.encode(input.absolute.path));
  if (projectRoot != null &&
      !_isUnderDirectory(input.absolute.path, projectRoot.path)) {
    return File('${projectRoot.path}/.dart_tool/quds/cache/$name.json');
  }
  return File('${input.parent.path}/.dart_tool/quds/cache/$name.json');
}

bool _cacheFresh(File cache, String sources, String output) {
  if (!cache.existsSync()) return false;
  final saved = jsonDecode(cache.readAsStringSync());
  return saved is Map &&
      saved['sources'] == sources &&
      saved['output'] == output &&
      _artifactsFresh(saved);
}

bool _artifactsFresh(Map saved) {
  if (saved['abi'] != _generatedAbi) return false;
  final artifacts = saved['artifacts'];
  if (artifacts is! Map) return false; // invalidate pre-graph caches once
  for (final entry in artifacts.entries) {
    if (entry.key is! String || entry.value is! String) return false;
    final file = File(entry.key as String);
    if (!file.existsSync() || sha256Hex(file.readAsBytesSync()) != entry.value)
      return false;
  }
  return true;
}

void _writeModels(File input, Compilation result) {
  final cache = _cacheFile(input);
  final previous = _savedGenerated(cache);
  final current = <String>[];
  final directory = Directory('${input.parent.path}/generated');
  for (final model in result.models) {
    current.add(model.fileName);
    final file = File('${directory.path}/${model.fileName}');
    file.parent.createSync(recursive: true);
    if (!file.existsSync() || file.readAsStringSync() != model.source) {
      file.writeAsStringSync(model.source);
    }
    final map = File('${file.path}.map');
    if (!map.existsSync() || map.readAsStringSync() != model.sourceMap) {
      map.writeAsStringSync(model.sourceMap);
    }
  }
  for (final name in previous) {
    if (current.contains(name)) continue;
    final file = File('${directory.path}/$name');
    if (file.existsSync()) file.deleteSync();
    final map = File('${file.path}.map');
    if (map.existsSync()) map.deleteSync();
  }
}

List<String> _savedGenerated(File cache) {
  if (!cache.existsSync()) return const [];
  final saved = jsonDecode(cache.readAsStringSync());
  if (saved is! Map) return const [];
  final names = saved['generated'];
  if (names is! List) return const [];
  return [for (final name in names) '$name'];
}

String _digestListed(List<String> paths, File input) {
  final bytes = BytesBuilder();
  bytes.add(utf8.encode('language ${_languageVersion(input)}\n'));
  for (final path in paths) {
    bytes.add(utf8.encode('$path\n'));
    final file = File(path);
    if (file.existsSync()) bytes.add(file.readAsBytesSync());
    bytes.add(const [0]);
  }
  bytes.add(utf8.encode('sdk\n'));
  bytes.add(utf8.encode(sdkDigestMaterial()));
  bytes.add(const [0]);
  return sha256Hex(bytes.takeBytes());
}

/// True when the generated Dart still matches the sources recorded last time.
bool _cachedOutput(File input, File output, {Directory? projectRoot}) {
  if (!output.existsSync()) return false;
  final cache = _cacheFile(input, projectRoot: projectRoot);
  if (!cache.existsSync()) return false;
  final saved = jsonDecode(cache.readAsStringSync());
  if (saved is! Map) return false;
  final paths = saved['paths'];
  if (paths is! List || paths.isEmpty) return false;
  final listed = [for (final path in paths) '$path'];
  final digest = _digestListed(listed, input);
  final outputDigest = sha256Hex(utf8.encode(output.readAsStringSync()));
  return saved['sources'] == digest &&
      saved['output'] == outputDigest &&
      _artifactsFresh(saved);
}

File? _ensureOutput(File input,
    [Set<String>? visited, Directory? projectRoot, String? configOrigin]) {
  final seen = visited ?? <String>{};
  final path = input.absolute.uri.normalizePath().toFilePath();
  final ownerRoot = projectRoot ?? _packageRoot(input.absolute.parent);
  final origin = configOrigin ?? path;
  final output = _outputFileForRoot(input, ownerRoot, configOrigin: origin);
  if (!seen.add(path)) return output;
  final List<String> dependencies;
  final cached = _cachedOutput(input, output, projectRoot: ownerRoot);
  if (cached) {
    final saved =
        jsonDecode(_cacheFile(input, projectRoot: ownerRoot).readAsStringSync())
            as Map;
    dependencies = (saved['paths'] as List).cast<String>();
  } else {
    final source = input.readAsStringSync();
    final result = compile(source, file: input.path, packageConfigFrom: origin);
    if (!_emitGenerated(input, result,
        announce: false,
        destination: output,
        projectRoot: ownerRoot,
        configOrigin: origin,
        sourceText: source)) return null;
    dependencies = result.dependencies;
  }
  for (final dependency in dependencies) {
    if (!dependency.endsWith('.quds') || dependency == path) continue;
    if (_ensureOutput(File(dependency), seen, ownerRoot, origin) == null) {
      return null;
    }
  }
  // A rebuilt dependency may replace a shared SDK bundle. Revalidate a cached
  // caller afterwards so it never calls helper names from the previous bundle.
  if (cached && !_cachedOutput(input, output, projectRoot: ownerRoot)) {
    final source = input.readAsStringSync();
    final result = compile(source, file: input.path, packageConfigFrom: origin);
    if (!_emitGenerated(input, result,
        announce: false,
        destination: output,
        projectRoot: ownerRoot,
        configOrigin: origin,
        sourceText: source)) return null;
  }
  return output;
}

String _languageVersion(File input) {
  final yaml = File('${input.parent.path}/quds.yaml');
  if (!yaml.existsSync()) return '1.2';
  final match = RegExp(r'^[ \t]*language:[ \t]*"?([^"\s#]+)"?', multiLine: true)
      .firstMatch(yaml.readAsStringSync());
  return match?.group(1) ?? '1.2';
}

String _stamp(List<String> paths) {
  final ordered = [...paths]..sort();
  final buffer = StringBuffer();
  for (final path in ordered) {
    final file = File(path);
    if (!file.existsSync()) {
      buffer.write('$path missing\n');
      continue;
    }
    buffer.write('$path ${sha256Hex(file.readAsBytesSync())}\n');
  }
  return buffer.toString();
}

Future<void> _run(List<String> arguments, {String? buildTarget}) async {
  final options = <String>[];
  final programArguments = <String>[];
  String? entry;
  String? evalCode;
  final rest = arguments.skip(1).toList();
  final separator = rest.indexOf('--');
  final toolArguments = separator < 0 ? rest : rest.take(separator).toList();
  if (toolArguments.contains('--help') || toolArguments.contains('-h')) {
    _help(['help', buildTarget == null ? 'run' : 'build']);
    return;
  }
  const valued = {
    '-d',
    '--device-id',
    '--dart-define',
    '--dart-define-from-file',
    '--flavor',
    '--web-port',
    '--web-hostname',
    '--web-renderer',
    '--route',
    '--device-timeout',
    '--target-platform',
    '--dds-port',
    '--host-vmservice-port',
    '-D',
    '--define',
    '--verbosity',
    '--write-service-info',
  };
  for (var i = 0; i < rest.length; i++) {
    final arg = rest[i];
    if (arg == '--') {
      programArguments.addAll(rest.skip(i + 1));
      break;
    }
    if (arg == '-e' || arg == '--eval' || arg.startsWith('--eval=')) {
      if (arg.startsWith('--eval=')) {
        evalCode = arg.substring('--eval='.length);
      } else {
        if (++i >= rest.length) {
          stderr.writeln('Missing code for $arg.');
          exitCode = 64;
          return;
        }
        evalCode = rest[i];
      }
      continue;
    }
    if (arg == '-t' ||
        arg == '--target' ||
        arg.startsWith('--target=') ||
        (arg.startsWith('-t') && !arg.startsWith('--'))) {
      final String target;
      if (arg == '-t' || arg == '--target') {
        if (++i >= rest.length) {
          stderr.writeln('Missing Quds target.');
          exitCode = 64;
          return;
        }
        target = rest[i];
      } else {
        target =
            arg.startsWith('--target=') ? arg.substring(9) : arg.substring(2);
      }
      if (entry != null || !target.endsWith('.quds')) {
        stderr.writeln('Specify one .quds entry point.');
        exitCode = 64;
        return;
      }
      entry = target;
    } else if (valued.contains(arg)) {
      options.add(arg);
      if (++i >= rest.length) {
        stderr.writeln('Missing value for $arg.');
        exitCode = 64;
        return;
      }
      options.add(rest[i]);
    } else if (entry == null && !arg.startsWith('-') && arg.endsWith('.quds')) {
      entry = arg;
    } else {
      options.add(arg);
    }
  }
  Directory? evalTemp;
  if (evalCode != null) {
    if (entry != null || buildTarget != null) {
      stderr.writeln(
          'Cannot combine -e/--eval with a .quds file or platform build.');
      exitCode = 64;
      return;
    }
    evalTemp = Directory.systemTemp.createTempSync('quds-eval-');
    final trimmed = evalCode.trimLeft();
    final hasMain = RegExp(r'(^|\n)main\s*\(').hasMatch(trimmed);
    final source = hasMain
        ? '$evalCode\n'
        : 'main():\n${evalCode.split('\n').map((line) => '  $line').join('\n')}\n';
    final evalFile = File('${evalTemp.path}/eval.quds')
      ..writeAsStringSync(source);
    entry = evalFile.path;
  }
  final root = _packageRoot(Directory.current);
  final input = entry != null
      ? File(entry)
      : File(
          '${root.path}/${File('${root.path}/lib/main.quds').existsSync() ? 'lib/main.quds' : 'main.quds'}');
  if (entry == null && !input.existsSync()) {
    stderr.writeln(
        'No lib/main.quds or main.quds found. Specify a .quds entry point.');
    exitCode = 64;
    return;
  }
  try {
    if (evalTemp == null && _flutterPackage(input)) {
      await _runFlutter(
          input,
          [
            ...options,
            if (programArguments.isNotEmpty) ...programArguments,
          ],
          buildTarget: buildTarget);
      return;
    }
    if (buildTarget != null) {
      stderr.writeln('Platform builds require a Flutter project.');
      exitCode = 64;
      return;
    }
    final vmFlags = <String>[];
    final plainArgs = <String>[];
    for (var i = 0; i < options.length; i++) {
      final arg = options[i];
      if (!arg.startsWith('-')) {
        plainArgs.add(arg);
        continue;
      }
      if (arg == '--enable-asserts' ||
          arg == '--no-enable-asserts' ||
          arg == '--observe' ||
          arg.startsWith('--observe=') ||
          arg == '--enable-vm-service' ||
          arg.startsWith('--enable-vm-service=') ||
          arg == '--pause-isolates-on-start' ||
          arg == '--pause-isolates-on-exit' ||
          arg == '--pause-isolates-on-unhandled-exceptions' ||
          arg == '--disable-service-auth-codes' ||
          arg.startsWith('--write-service-info=') ||
          arg.startsWith('--verbosity=') ||
          arg.startsWith('--define=') ||
          (arg.startsWith('-D') && arg.length > 2)) {
        if (arg != '--no-enable-asserts') vmFlags.add(arg);
      } else if (arg == '-D' || arg == '--define') {
        if (i + 1 >= options.length) {
          stderr.writeln('Missing value for $arg.');
          exitCode = 64;
          return;
        }
        vmFlags.add('-D${options[++i]}');
      } else if (arg == '--verbosity' || arg == '--write-service-info') {
        if (i + 1 >= options.length) {
          stderr.writeln('Missing value for $arg.');
          exitCode = 64;
          return;
        }
        vmFlags.add('$arg=${options[++i]}');
      } else {
        stderr.writeln(
            'Unknown flag for quds run: $arg. Pass program flags after --.');
        exitCode = 64;
        return;
      }
    }
    final output = _ensureOutput(input);
    if (output == null) return;
    final mapFile = File('${output.path}.map');
    final sourceMap = mapFile.existsSync() ? mapFile.readAsStringSync() : null;
    final generatedName = output.uri.pathSegments.last;
    final qudsSource = input.existsSync() ? input.readAsStringSync() : null;
    final process = await Process.start(
      _dartExecutable(),
      _withPackages(
          [...vmFlags, output.path, ...plainArgs, ...programArguments],
          input: evalTemp == null ? input : null),
      workingDirectory: evalTemp == null
          ? _packageRoot(input.absolute.parent).path
          : Directory.current.path,
    );
    final streams = Future.wait([
      _copyMapped(process.stdout, stdout, sourceMap, generatedName,
          qudsSource: qudsSource),
      _copyMapped(process.stderr, stderr, sourceMap, generatedName,
          qudsSource: qudsSource),
    ]);
    exitCode = await process.exitCode;
    await streams;
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  } finally {
    if (evalTemp != null && evalTemp.existsSync()) {
      evalTemp.deleteSync(recursive: true);
    }
  }
}

Future<void> _copyMapped(Stream<List<int>> input, IOSink output,
    String? sourceMap, String generatedName,
    {String? qudsSource}) async {
  final pending = StringBuffer();
  await for (final chunk in input.transform(utf8.decoder)) {
    pending.write(chunk);
    final text = pending.toString();
    final end = text.lastIndexOf('\n');
    if (end < 0) continue;
    pending.clear();
    pending.write(text.substring(end + 1));
    output.write(_atQuds(text.substring(0, end + 1), sourceMap, generatedName,
        qudsSource: qudsSource));
  }
  if (pending.isNotEmpty) {
    output.write(_atQuds(pending.toString(), sourceMap, generatedName,
        qudsSource: qudsSource));
  }
}

// Stage Quds modules at unique temporary URIs. Re-emitting directives from AST
// preserves source libraries and gives every module the same SDK bundle identity.
(File, Compilation) _temporaryDartTree(
    File input, Compilation root, Directory directory) {
  String canonical(String path) =>
      File(path).absolute.uri.normalizePath().toFilePath();
  String fileUri(String path) =>
      Uri.file(path).toString().replaceAll(r'$', '%24').replaceAll("'", '%27');
  final inputPath = canonical(input.path);
  final paths = <String>{
    inputPath,
    for (final path in root.dependencies)
      if (path.endsWith('.quds')) canonical(path)
  }.toList();
  final targets = {
    for (var i = 0; i < paths.length; i++)
      paths[i]: File('${directory.path}/module$i.dart')
  };
  Compilation? stagedRoot;
  for (final path in paths) {
    final compiled = path == inputPath
        ? root
        : compile(File(path).readAsStringSync(),
            file: path, packageConfigFrom: inputPath);
    walkAst(compiled.program, (node) {
      if (node is ImportDeclaration && !node.uri.startsWith('quds:')) {
        final target =
            resolveLibraryPath(path, node.uri, packageConfigFrom: inputPath);
        final staged = target == null ? null : targets[canonical(target)];
        if (staged != null) {
          compiled.semantics.resolvedImports[node] = fileUri(staged.path);
        } else {
          final uri = libraryTarget(node.uri);
          if (uri.endsWith('.dart') && !Uri.parse(uri).hasScheme) {
            compiled.semantics.resolvedImports[node] =
                fileUri(Uri.file(path).resolve(uri).toFilePath());
          }
        }
      } else if (node is PartDirective && node.uri.endsWith('.quds')) {
        final target = canonical(Uri.file(path).resolve(node.uri).toFilePath());
        if (targets[target] case final staged?) {
          compiled.semantics.resolvedParts[node] = fileUri(staged.path);
        }
      }
    });
    for (final entry
        in compiled.semantics.backendTypeImports.entries.toList()) {
      String? sourcePath;
      if (entry.value.startsWith('package:')) {
        sourcePath =
            resolveLibraryPath(path, entry.value, packageConfigFrom: inputPath);
      } else {
        final uri = Uri.parse(entry.value);
        final typePath = uri.scheme == 'file'
            ? uri.toFilePath()
            : !uri.hasScheme
                ? Uri.file(path).resolve(entry.value).toFilePath()
                : null;
        if (typePath != null && typePath.endsWith('.dart')) {
          sourcePath = '${typePath.substring(0, typePath.length - 5)}.quds';
        }
      }
      if (sourcePath == null) continue;
      final target = targets[canonical(sourcePath)];
      if (target != null)
        compiled.semantics.backendTypeImports[entry.key] = fileUri(target.path);
    }
    final emitter = DartEmitter(compiled.semantics);
    final dart = emitter.emit(compiled.program);
    final target = targets[path]!;
    target.writeAsStringSync(dart);
    writeSdkBundles(directory.path, compiled);
    if (path == inputPath) {
      stagedRoot = Compilation(compiled.program, compiled.semantics, dart,
          sourceMap: sourceMapFor(emitter, target.path, path,
              program: compiled.program, source: input.readAsStringSync()),
          dependencies: compiled.dependencies,
          models: compiled.models,
          bundles: compiled.bundles);
    }
  }
  return (targets[inputPath]!, stagedRoot!);
}

void _analyze(List<String> arguments) {
  final dartFlags = <String>[];
  final targets = <String>[];
  for (var i = 1; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--fatal-infos' ||
        arg == '--fatal-warnings' ||
        arg == '--no-fatal-warnings') {
      dartFlags.add(arg);
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for analyze: $arg');
      exitCode = 64;
      return;
    } else {
      targets.add(arg);
    }
  }
  if (targets.isEmpty) targets.add('.');

  final files = <File>[];
  final seen = <String>{};
  for (final target in targets) {
    final type = FileSystemEntity.typeSync(target);
    if (type == FileSystemEntityType.notFound) {
      stderr.writeln('Cannot open file: $target');
      exitCode = 74;
      return;
    }
    if (type == FileSystemEntityType.file) {
      if (!target.endsWith('.quds')) {
        stderr.writeln('Expected a .quds file: $target');
        exitCode = 64;
        return;
      }
      final file = File(target);
      if (seen.add(file.absolute.path)) files.add(file);
    } else if (type == FileSystemEntityType.directory) {
      _collectQudsFiles(Directory(target), files, seen);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stdout.writeln('No .quds files found.');
    return;
  }

  final singleExplicitFile =
      targets.length == 1 && FileSystemEntity.isFileSync(targets.first);
  var worstExit = 0;
  var failedCount = 0;
  for (final input in files) {
    final code =
        _analyzeOne(input, dartFlags, quietSuccess: !singleExplicitFile);
    if (code != 0) {
      failedCount++;
      if (worstExit == 0) worstExit = code;
    }
  }
  if (!singleExplicitFile) {
    if (failedCount == 0) {
      stdout.writeln(
          'Analyzed ${files.length} file${files.length == 1 ? '' : 's'}: no issues found.');
    } else {
      stderr.writeln(
          'Analyzed ${files.length} file${files.length == 1 ? '' : 's'}: $failedCount failed.');
    }
  }
  exitCode = worstExit;
}

int _analyzeOne(File input, List<String> dartFlags,
    {bool quietSuccess = false}) {
  try {
    final result = compile(input.readAsStringSync(), file: input.path);
    final directory = Directory.systemTemp.createTempSync('quds-analyze-');
    try {
      final (output, staged) = _temporaryDartTree(input, result, directory);
      final analysis = Process.runSync(_dartExecutable(),
          _withPackages(['analyze', ...dartFlags, output.path], input: input));
      if (!quietSuccess || analysis.exitCode != 0) {
        _writeQuds(analysis.stdout, analysis.stderr, staged.sourceMap,
            output.uri.pathSegments.last);
      }
      return analysis.exitCode;
    } finally {
      directory.deleteSync(recursive: true);
    }
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    return 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    return 74;
  }
}

void _test(List<String> arguments) {
  final regexPatterns = <String>[];
  final plainPatterns = <String>[];
  var failFast = false;
  var enableAsserts = true;
  var reporter = 'compact';
  final targets = <String>[];

  for (var i = 1; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '-n' || arg == '--name') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing pattern for $arg');
        exitCode = 64;
        return;
      }
      regexPatterns.add(arguments[++i]);
    } else if (arg.startsWith('--name=')) {
      regexPatterns.add(arg.substring('--name='.length));
    } else if (arg == '-N' || arg == '--plain-name') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing substring for $arg');
        exitCode = 64;
        return;
      }
      plainPatterns.add(arguments[++i]);
    } else if (arg.startsWith('--plain-name=')) {
      plainPatterns.add(arg.substring('--plain-name='.length));
    } else if (arg == '--fail-fast') {
      failFast = true;
    } else if (arg == '--enable-asserts') {
      enableAsserts = true;
    } else if (arg == '--no-enable-asserts') {
      enableAsserts = false;
    } else if (arg == '-r' || arg == '--reporter') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing value for $arg');
        exitCode = 64;
        return;
      }
      reporter = arguments[++i];
    } else if (arg.startsWith('--reporter=')) {
      reporter = arg.substring('--reporter='.length);
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for test: $arg');
      exitCode = 64;
      return;
    } else {
      targets.add(arg);
    }
  }
  if (reporter != 'compact' && reporter != 'expanded') {
    stderr
        .writeln('Unknown reporter: $reporter (expected compact or expanded)');
    exitCode = 64;
    return;
  }
  for (final pattern in regexPatterns) {
    try {
      RegExp(pattern);
    } on FormatException catch (error) {
      stderr.writeln('Invalid --name regex "$pattern": ${error.message}');
      exitCode = 64;
      return;
    }
  }

  final explicitSingleFile =
      targets.length == 1 && FileSystemEntity.isFileSync(targets.first);
  if (targets.isEmpty) {
    if (Directory('test').existsSync()) {
      targets.add('test');
    } else {
      targets.add('.');
    }
  }

  final files = <File>[];
  final seen = <String>{};
  for (final target in targets) {
    final type = FileSystemEntity.typeSync(target);
    if (type == FileSystemEntityType.notFound) {
      stderr.writeln('Cannot open file: $target');
      exitCode = 74;
      return;
    }
    if (type == FileSystemEntityType.file) {
      if (!target.endsWith('.quds')) {
        stderr.writeln('Expected a .quds file: $target');
        exitCode = 64;
        return;
      }
      final file = File(target);
      if (seen.add(file.absolute.path)) files.add(file);
    } else if (type == FileSystemEntityType.directory) {
      final collected = <File>[];
      _collectQudsFiles(Directory(target), collected, <String>{});
      final namedTests =
          collected.where((f) => f.path.endsWith('_test.quds')).toList();
      final selected = namedTests.isNotEmpty
          ? namedTests
          : collected.where((f) {
              final text = f.readAsStringSync();
              return RegExp(r'^(test|group)\s+"|^when\s+test\s*:',
                      multiLine: true)
                  .hasMatch(text);
            }).toList();
      for (final file in selected) {
        if (seen.add(file.absolute.path)) files.add(file);
      }
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('No test files found.');
    exitCode = 1;
    return;
  }

  var passedSuites = 0;
  var worstExit = 0;
  for (final input in files) {
    if (!explicitSingleFile || reporter == 'expanded') {
      stdout.writeln('==> ${input.path}');
    }
    final code = _runTestFile(
      input,
      regexPatterns: regexPatterns,
      plainPatterns: plainPatterns,
      failFast: failFast,
      enableAsserts: enableAsserts,
    );
    if (code == 0) {
      passedSuites++;
    } else {
      if (worstExit == 0) worstExit = code;
      if (failFast) break;
    }
  }
  if (!explicitSingleFile || reporter == 'expanded') {
    stdout.writeln(
        '$passedSuites/${files.length} test file${files.length == 1 ? '' : 's'} passed.');
  }
  exitCode = worstExit;
}

Iterable<Statement> _activeTestStatements(
    List<Statement> statements, SemanticModel semantics) sync* {
  for (final statement in statements) {
    if (semantics.skipped.contains(statement)) continue;
    if (statement is WhenStatement) {
      yield* _activeTestStatements(statement.body, semantics);
    } else {
      yield statement;
    }
  }
}

int _runTestFile(
  File input, {
  required List<String> regexPatterns,
  required List<String> plainPatterns,
  required bool failFast,
  required bool enableAsserts,
}) {
  try {
    final result =
        compile(input.readAsStringSync(), file: input.path, testing: true);
    final activeTop =
        _activeTestStatements(result.program.statements, result.semantics)
            .toList();
    final tests = activeTop.whereType<TestDeclaration>().toList();
    final hasFilter = regexPatterns.isNotEmpty || plainPatterns.isNotEmpty;
    bool matchesName(String name) {
      for (final pattern in regexPatterns) {
        if (!RegExp(pattern).hasMatch(name)) return false;
      }
      for (final plain in plainPatterns) {
        if (!name.contains(plain)) return false;
      }
      return true;
    }

    final legacy = activeTop
        .whereType<FunctionDeclaration>()
        .where((function) =>
            (function.name == 'test' || function.name.startsWith('test')) &&
            function.parameters.isEmpty &&
            function.generator.isEmpty &&
            (!hasFilter || matchesName(function.name)))
        .toList();
    bool hasTest(TestDeclaration declaration) =>
        declaration.kind == 'test' ||
        declaration.body.whereType<TestDeclaration>().any(hasTest);
    if (!tests.any(hasTest) && legacy.isEmpty) {
      stderr.writeln('No tests found in ${input.path}');
      return 1;
    }
    // Use a separate driver so a source main() cannot bypass test discovery.
    // Only this appended bridge sees private generated test declarations.
    final occupied = result.semantics.declarations.values
        .expand((symbol) => [symbol.name, symbol.dartName])
        .toSet();
    var entry = 'qudsTestEntrypoint';
    var suffix = 0;
    while (occupied.contains(entry)) {
      entry = 'qudsTestEntrypoint${++suffix}';
    }
    final setup = StringBuffer();
    if (tests.isNotEmpty && failFast) {
      setup.writeln('  _qTestFailFast = true;');
    }
    if (tests.isNotEmpty && hasFilter) {
      final checks = <String>[
        for (final p in regexPatterns)
          'RegExp(${jsonEncode(p).replaceAll(r'$', r'\$')}).hasMatch(name)',
        for (final p in plainPatterns)
          'name.contains(${jsonEncode(p).replaceAll(r'$', r'\$')})',
      ];
      setup.writeln('  _qTestFilter = (name) => ${checks.join(' && ')};');
    }
    final calls = [
      ...tests.map((test) =>
          '  await ${result.semantics.declarations[test]!.dartName}();'),
      ...legacy.map((function) => '  ${function.isAsync ? 'await ' : ''}'
          '${result.semantics.declarations[function]!.dartName}();'),
    ].join('\n');
    // A raw failure count of 256 becomes a successful exit on POSIX.
    final status = tests.isNotEmpty ? '_qTestFailed == 0 ? 0 : 1' : '0';
    if (result.dart.contains('package:matcher/') &&
        _packageConfigPath() == null) {
      stderr.writeln('Could not find the package config for matcher');
      return 1;
    }
    final directory = Directory.systemTemp.createTempSync('quds-test-');
    try {
      final (suite, staged) = _temporaryDartTree(input, result, directory);
      suite.writeAsStringSync('${staged.dart}\nFuture<int> $entry() async {\n'
          '$setup$calls\n  return $status;\n}\n');
      final suiteUri = jsonEncode(suite.uri.toString()).replaceAll(r'$', r'\$');
      final output = File('${directory.path}/main.dart')
        ..writeAsStringSync("import 'dart:io' as io;\n"
            'import $suiteUri as suite;\n'
            'Future<void> main() async {\n'
            '  io.exitCode = await suite.$entry();\n}\n');
      final run = Process.runSync(
          _dartExecutable(),
          _withPackages([if (enableAsserts) '--enable-asserts', output.path],
              input: input));
      _writeQuds(run.stdout, run.stderr, staged.sourceMap,
          suite.uri.pathSegments.last);
      return run.exitCode;
    } finally {
      directory.deleteSync(recursive: true);
    }
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    return 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    return 74;
  }
}

void _format(List<String> arguments) {
  var check = false;
  var outputMode = 'write';
  var indent = 2;
  var width = 80;
  var singleLineIf = true;
  final targets = <String>[];

  int? parsePositiveInt(String flag, String raw) {
    final value = int.tryParse(raw);
    if (value == null || value < 1) {
      stderr.writeln('Invalid value for $flag: $raw');
      exitCode = 64;
      return null;
    }
    return value;
  }

  for (var i = 1; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--check' || arg == '--set-exit-if-changed') {
      check = true;
    } else if (arg == '--stdout') {
      outputMode = 'show';
    } else if (arg == '-o' || arg == '--output') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing value for $arg');
        exitCode = 64;
        return;
      }
      outputMode = arguments[++i];
    } else if (arg.startsWith('--output=')) {
      outputMode = arg.substring('--output='.length);
    } else if (arg == '--no-single-line-if') {
      singleLineIf = false;
    } else if (arg == '--indent') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing value for --indent');
        exitCode = 64;
        return;
      }
      final parsed = parsePositiveInt('--indent', arguments[++i]);
      if (parsed == null) return;
      indent = parsed;
    } else if (arg.startsWith('--indent=')) {
      final parsed =
          parsePositiveInt('--indent', arg.substring('--indent='.length));
      if (parsed == null) return;
      indent = parsed;
    } else if (arg == '-l' || arg == '--width' || arg == '--line-length') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing value for $arg');
        exitCode = 64;
        return;
      }
      final parsed = parsePositiveInt(arg, arguments[++i]);
      if (parsed == null) return;
      width = parsed;
    } else if (arg.startsWith('--width=')) {
      final parsed =
          parsePositiveInt('--width', arg.substring('--width='.length));
      if (parsed == null) return;
      width = parsed;
    } else if (arg.startsWith('--line-length=')) {
      final parsed = parsePositiveInt(
          '--line-length', arg.substring('--line-length='.length));
      if (parsed == null) return;
      width = parsed;
    } else if (arg.startsWith('-l') && arg.length > 2) {
      final parsed = parsePositiveInt('-l', arg.substring(2));
      if (parsed == null) return;
      width = parsed;
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for format: $arg');
      exitCode = 64;
      return;
    } else {
      targets.add(arg);
    }
  }

  if (!const {'write', 'show', 'none'}.contains(outputMode)) {
    stderr.writeln(
        'Invalid value for --output: $outputMode (expected write, show, or none)');
    exitCode = 64;
    return;
  }
  final toStdout = outputMode == 'show';
  final dryRun = outputMode == 'none' || check;

  if (targets.isEmpty) targets.add('.');

  final files = <File>[];
  final seen = <String>{};
  for (final target in targets) {
    final type = FileSystemEntity.typeSync(target);
    if (type == FileSystemEntityType.notFound) {
      stderr.writeln('Cannot open file: $target');
      exitCode = 74;
      return;
    }
    if (type == FileSystemEntityType.file) {
      if (!target.endsWith('.quds')) {
        stderr.writeln('Expected a .quds file: $target');
        exitCode = 64;
        return;
      }
      final file = File(target);
      final key = file.absolute.path;
      if (seen.add(key)) files.add(file);
    } else if (type == FileSystemEntityType.directory) {
      _collectQudsFiles(Directory(target), files, seen);
    }
  }

  if (toStdout && files.length != 1) {
    stderr.writeln('--stdout / --output=show requires a single .quds file.');
    exitCode = 64;
    return;
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  var changed = 0;
  var hadError = false;
  final singleFileTarget =
      targets.length == 1 && FileSystemEntity.isFileSync(targets.first);

  for (final input in files) {
    try {
      final source = input.readAsStringSync();
      Parser(Lexer().tokenize(source, file: input.path)).parse();
      final formatted = formatQuds(
        source,
        indent: indent,
        width: width,
        singleLineIf: singleLineIf,
      );
      if (toStdout) {
        stdout.write(formatted);
        if (check && formatted != source) exitCode = 1;
        return;
      }
      final diff = formatted != source;
      if (dryRun) {
        if (diff) {
          changed++;
          stdout.writeln('Unformatted ${input.path}');
        }
      } else {
        if (diff) {
          input.writeAsStringSync(formatted);
          changed++;
        }
        if (singleFileTarget || diff) {
          stdout.writeln('Formatted ${input.path}');
        }
      }
    } on CompilerException catch (error) {
      _reportCompilerError(error);
      hadError = true;
      exitCode = 65;
    } on FileSystemException catch (error) {
      stderr.writeln(error.message);
      hadError = true;
      exitCode = 74;
    }
  }

  if (hadError) return;
  if (check) {
    if (changed > 0) {
      exitCode = 1;
    }
    return;
  }
  if (!singleFileTarget) {
    stdout.writeln(
        'Formatted ${files.length} file${files.length == 1 ? '' : 's'} ($changed changed).');
  }
}

void _collectQudsFiles(Directory dir, List<File> out, Set<String> seen) {
  const skipped = {
    '.git',
    '.dart_tool',
    '.quds_backup',
    'build',
    'node_modules',
  };
  for (final entity in dir.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    if (entity is Directory) {
      if (name != null && skipped.contains(name)) continue;
      _collectQudsFiles(entity, out, seen);
    } else if (entity is File && entity.path.endsWith('.quds')) {
      final key = entity.absolute.path;
      if (seen.add(key)) out.add(entity);
    }
  }
}

Future<void> _create(List<String> arguments) async {
  if (arguments.length >= 2 && arguments[1] == '.') {
    _createPlatforms(arguments.skip(2).toList());
    return;
  }
  if (arguments.length >= 2 && arguments[1] == 'flutter') {
    if (arguments.length != 3) {
      stderr.writeln('Usage: quds create --f <name>');
      exitCode = 64;
      return;
    }
    _createFlutter(arguments[2]);
    return;
  }
  var template = 'console';
  var force = false;
  var runPub = false;
  String? name;
  for (var i = 1; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--f' || arg == '-f' || arg == '--flutter') {
      template = 'flutter';
    } else if (arg == '-t' || arg == '--template') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing template name for $arg');
        exitCode = 64;
        return;
      }
      template = arguments[++i];
    } else if (arg.startsWith('--template=')) {
      template = arg.substring('--template='.length);
    } else if (arg == '--force') {
      force = true;
    } else if (arg == '--pub') {
      runPub = true;
    } else if (arg == '--no-pub') {
      runPub = false;
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for create: $arg');
      exitCode = 64;
      return;
    } else if (name == null) {
      name = arg;
    } else {
      stderr.writeln(
          'Usage: quds create [--f | -t <console|cli|package|flutter>] [--force] [--[no-]pub] <name>');
      exitCode = 64;
      return;
    }
  }
  if (name == null) {
    stderr.writeln('Usage: quds create <name>');
    stderr.writeln('       quds create --f <name>');
    stderr
        .writeln('       quds create -t <console|cli|package|flutter> <name>');
    exitCode = 64;
    return;
  }
  if (!const {'console', 'cli', 'package', 'flutter'}.contains(template)) {
    stderr.writeln(
        'Unknown template: $template (expected console, cli, package, or flutter)');
    exitCode = 64;
    return;
  }
  if (template == 'flutter') {
    _createFlutter(name);
    return;
  }
  final directory = Directory(name);
  if (directory.existsSync() && !force) {
    stderr.writeln('Directory already exists: $name');
    exitCode = 73;
    return;
  }
  final pkgName = name
      .replaceAll('\\', '/')
      .split('/')
      .where((part) => part.isNotEmpty)
      .last
      .replaceAll('-', '_');
  directory.createSync(recursive: true);
  File('$name/quds.yaml').writeAsStringSync('language: 1.2\nname: $pkgName\n');
  File('$name/pubspec.yaml').writeAsStringSync(
      'name: $pkgName\nversion: 0.1.0\nenvironment:\n  sdk: ">=3.3.0 <4.0.0"\n');
  if (template == 'console') {
    File('$name/main.quds').writeAsStringSync('main():\n  print "$pkgName"\n');
  } else if (template == 'cli') {
    Directory('$name/bin').createSync(recursive: true);
    Directory('$name/lib').createSync(recursive: true);
    Directory('$name/test').createSync(recursive: true);
    File('$name/lib/$pkgName.quds')
        .writeAsStringSync('greet(who: String) -> String = "Hello, {who}!"\n');
    File('$name/bin/$pkgName.quds').writeAsStringSync('''
use package:$pkgName

main(args: List<String>):
  who = if args.isEmpty: "$pkgName" else: args.first
  print greet(who)
''');
    File('$name/test/${pkgName}_test.quds').writeAsStringSync('''
use package:$pkgName

test "greet formats name":
  expect(greet("Quds"), equals("Hello, Quds!"))
''');
  } else if (template == 'package') {
    Directory('$name/lib/src').createSync(recursive: true);
    Directory('$name/test').createSync(recursive: true);
    File('$name/lib/src/${pkgName}_base.quds').writeAsStringSync('''
class ${pkgName[0].toUpperCase()}${pkgName.substring(1)}Info:
  name: String
''');
    File('$name/lib/$pkgName.quds').writeAsStringSync('''
use package:$pkgName/src/${pkgName}_base
export package:$pkgName/src/${pkgName}_base

/// Returns a greeting from $pkgName.
greet(who: String) -> String = "Hello from $pkgName, {who}!"
''');
    File('$name/test/${pkgName}_test.quds').writeAsStringSync('''
use package:$pkgName

test "$pkgName public API":
  expect(greet("Quds"), equals("Hello from $pkgName, Quds!"))
''');
    File('$name/README.md').writeAsStringSync('''
# $pkgName

A Quds package.

- Run tests: `quds test`
- Build Dart files for dual Quds + Dart/Flutter publishing: `quds build --package`
''');
  }
  stdout.writeln('Created $name');
  if (runPub) {
    await _pubCommand(['get', '-C', directory.path]);
  }
}

void _createPlatforms(List<String> arguments) {
  if (arguments
      .any((arg) => arg == '--overwrite' || arg == '--overwrite=true')) {
    stderr.writeln(
        'create . preserves existing project files; --overwrite is not supported.');
    exitCode = 64;
    return;
  }
  final flutter = _flutterExecutable();
  if (flutter == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final root = Directory.current;
  final spec = File('${root.path}/pubspec.yaml');
  String? updatedSpec;
  String? name;
  if (spec.existsSync()) {
    try {
      final editor = YamlEditor(spec.readAsStringSync());
      final values = editor.parseAt([]).value as Map;
      name = values['name'] as String?;
      final dependencies = values['dependencies'];
      if (dependencies == null)
        editor.update(['dependencies'], <String, Object?>{});
      if (dependencies != null && dependencies is! Map)
        throw FormatException('dependencies must be a mapping');
      if (dependencies is! Map ||
          dependencies['flutter'] is! Map ||
          dependencies['flutter']['sdk'] != 'flutter') {
        editor.update(['dependencies', 'flutter'], {'sdk': 'flutter'});
      }
      updatedSpec = editor.toString();
    } catch (error) {
      stderr.writeln('Cannot update pubspec.yaml: $error');
      exitCode = 65;
      return;
    }
  }
  final saved = <String, List<int>?>{
    for (final path in [
      'pubspec.yaml',
      'pubspec.lock',
      'quds.yaml',
      'lib/main.dart',
      'test/widget_test.dart'
    ])
      path: File('${root.path}/$path').existsSync()
          ? File('${root.path}/$path').readAsBytesSync()
          : null,
  };
  final forwarded =
      arguments.where((arg) => arg != '--pub' && arg != '--no-pub').toList();
  if (name != null &&
      !arguments.any(
          (a) => a == '--project-name' || a.startsWith('--project-name='))) {
    forwarded.addAll(['--project-name', name]);
  }
  final result =
      Process.runSync(flutter, ['create', ...forwarded, '--no-pub', '.']);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  for (final entry in saved.entries) {
    final file = File('${root.path}/${entry.key}');
    if (entry.value != null) {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(entry.value!);
    } else if ({'lib/main.dart', 'test/widget_test.dart'}.contains(entry.key) &&
        file.existsSync()) {
      file.deleteSync();
    }
  }
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }
  if (updatedSpec != null) spec.writeAsStringSync(updatedSpec);
  final entry = File('${root.path}/lib/main.quds');
  if (!entry.existsSync()) {
    entry.parent.createSync(recursive: true);
    entry.writeAsStringSync(flutterApp);
  }
  final configuration = File('${root.path}/quds.yaml');
  if (!configuration.existsSync())
    configuration.writeAsStringSync('language: 1.2\n');
  _ignoreGenerated(root.path);
  if (!arguments.contains('--no-pub')) {
    final resolved = Process.runSync(flutter, ['pub', 'get']);
    stdout.write(resolved.stdout);
    stderr.write(resolved.stderr);
    if (resolved.exitCode != 0) {
      exitCode = resolved.exitCode;
      return;
    }
  }
  stdout.writeln('Flutter platforms configured. Run: quds run -d <device>');
}

void _createFlutter(String name) {
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    stderr.writeln(
        'A Flutter project name must start with a letter and use only lowercase letters, digits, and underscores: $name');
    exitCode = 64;
    return;
  }
  if (Directory(name).existsSync()) {
    stderr.writeln('Directory already exists: $name');
    exitCode = 73;
    return;
  }
  final flutter = _flutterExecutable();
  if (flutter == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final created = Process.runSync(flutter, ['create', name]);
  stdout.write(created.stdout);
  stderr.write(created.stderr);
  if (created.exitCode != 0) {
    exitCode = created.exitCode;
    return;
  }
  final mainDart = File('$name/lib/main.dart');
  if (mainDart.existsSync()) mainDart.deleteSync();
  final widgetTest = File('$name/test/widget_test.dart');
  if (widgetTest.existsSync()) widgetTest.deleteSync();
  Directory('$name/lib').createSync(recursive: true);
  File('$name/lib/main.quds').writeAsStringSync(flutterApp);
  File('$name/quds.yaml').writeAsStringSync('language: 1.2\nname: $name\n');
  _ignoreGenerated(name);
  stdout.writeln('Created Flutter project $name');
  stdout.writeln('Run it with: quds run $name/lib/main.quds');
}

void _ignoreGenerated(String name) {
  final ignore = File('$name/.gitignore');
  const entry = 'lib/quds_gen/';
  if (!ignore.existsSync()) {
    ignore.writeAsStringSync('$entry\n');
    return;
  }
  final text = ignore.readAsStringSync();
  if (text.contains(entry)) return;
  final separator = text.isEmpty || text.endsWith('\n') ? '' : '\n';
  ignore.writeAsStringSync('$text$separator$entry\n');
}

bool _flutterPackage(File input) => packageUsesFlutter(input.path);

String _flutterPlatform(List<String> arguments,
    {String? buildTarget, String? device}) {
  if (buildTarget == 'web') return 'web';
  for (var index = 0; index < arguments.length; index++) {
    final option = arguments[index];
    if ((option == '-d' || option == '--device-id') &&
        index + 1 < arguments.length)
      device = arguments[++index];
    else if (option.startsWith('--device-id='))
      device = option.substring(12);
    else if (option.startsWith('-d') &&
        !option.startsWith('--') &&
        option.length > 2) device = option.substring(2);
  }
  return {'chrome', 'edge', 'web-server'}.contains(device) ? 'web' : 'flutter';
}

class _FlutterPreparation {
  const _FlutterPreparation(this.root, this.target, this.relative, this.build,
      this.snapshot, this.failureCode, this.error, this.files);
  final Directory root;
  final File target;
  final String relative;
  final bool Function() build;
  final String Function() snapshot;
  final int Function() failureCode;
  final String? Function() error;
  final List<String> Function() files;
}

_FlutterPreparation _prepareFlutter(File input,
    {bool guardMain = true,
    String targetPlatform = 'flutter',
    void Function(String)? onProgress}) {
  final root = _packageRoot(input.absolute.parent);
  final origin = input.absolute.path;
  final target = _flutterGenerated(input, root);
  final relative = _relativePosix(root, target);
  final tracked = <String>{origin};
  final compiledCache = <String, (String, Compilation)>{};
  late String Function() currentSources;
  var buildFailure = 65;
  String? lastError;
  var lastFiles = <String>[];
  void report(Object error) {
    lastError = '$error';
    stderr.writeln(error);
  }

  String displaySource(File file) {
    final full = file.absolute.path;
    if (_isUnderDirectory(full, root.path)) return _relativePosix(root, file);
    final info = packageFileInfo(full, packageConfigFrom: origin);
    if (info != null) return 'package:${info.name}/${info.relativeInsideLib}';
    return full;
  }

  bool build() {
    final saved = exitCode;
    exitCode = 0;
    buildFailure = 65;
    lastError = null;
    try {
      // Validate the entire dependency graph before touching running output.
      final plan = <(File, Compilation)>[];
      final seen = <String>{};
      void prepare(File file) {
        final path = file.absolute.uri.normalizePath().toFilePath();
        if (!seen.add(path)) return;
        tracked.add(path);
        final cached = compiledCache[path];
        final Compilation compiled;
        if (cached != null &&
            cached.$1 == _stamp({...cached.$2.dependencies, path}.toList())) {
          compiled = cached.$2;
        } else {
          onProgress?.call('Quds: compiling ${displaySource(file)}...');
          final before = currentSources();
          compiled = compile(
            file.readAsStringSync(),
            file: path,
            targetPlatform: targetPlatform,
            flutter: true,
            packageConfigFrom: origin,
          );
          tracked
              .addAll(compiled.dependencies.where((p) => p.endsWith('.quds')));
          if (before == currentSources()) {
            compiledCache[path] =
                (_stamp({...compiled.dependencies, path}.toList()), compiled);
          }
        }
        plan.add((file, compiled));
        for (final dependency in compiled.dependencies) {
          if (dependency.endsWith('.quds')) prepare(File(dependency));
        }
      }

      prepare(input);
      for (final (file, _) in plan) {
        final output =
            _outputFileForRoot(file, root, flutter: true, configOrigin: origin);
        if (output.existsSync() &&
            !output.readAsStringSync().startsWith(_generatedHeader)) {
          report('Refusing to overwrite non-generated file: ${output.path}');
          buildFailure = 73;
          return false;
        }
      }
      onProgress?.call(
          'Quds: emitting ${plan.length} generated Dart file(s) -> lib/quds_gen/...');
      final artifactRoot = Directory(_join(root.path, 'lib/quds_gen'));
      for (final (file, compiled) in plan) {
        final output =
            _outputFileForRoot(file, root, flutter: true, configOrigin: origin);
        if (!_emitGenerated(
          file,
          compiled,
          announce: false,
          destination: output,
          artifactRoot: artifactRoot,
          projectRoot: root,
          configOrigin: origin,
          flutter: true,
        )) {
          buildFailure = exitCode == 0 ? 65 : exitCode;
          return false;
        }
      }
      final main = plan.first.$2;
      final generated = target.readAsStringSync();
      if (guardMain && main.sourceMap != null) {
        final suffix = relative.substring(relative.indexOf('quds_gen/'));
        target.writeAsStringSync(
            _guardGeneratedMain(generated, main.sourceMap!, suffix));
      }
      tracked.addAll(seen);
      lastFiles = seen.toList();
      return true;
    } on CompilerException catch (error) {
      report(error);
      return false;
    } on FileSystemException catch (error) {
      report(error);
      buildFailure = 74;
      return false;
    } finally {
      exitCode = saved;
    }
  }

  String snapshot() {
    final paths = <String>{...tracked};
    void scan(Directory directory) {
      if (!directory.existsSync()) return;
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
          if (!{'.git', '.dart_tool', '.quds_backup', 'build', 'quds_gen'}
              .contains(name)) scan(entity);
        } else if (entity is File && entity.path.endsWith('.quds')) {
          paths.add(entity.absolute.path);
        }
      }
    }

    scan(root);
    return _stamp(paths.toList());
  }

  currentSources = snapshot;
  return _FlutterPreparation(root, target, relative, build, snapshot,
      () => buildFailure, () => lastError, () => lastFiles);
}

final _debugFlutterGraphs = <String, _FlutterPreparation>{};

Future<void> _runFlutter(File input, List<String> arguments,
    {String? buildTarget}) async {
  if (arguments.any((arg) =>
      (arg.startsWith('-t') && !arg.startsWith('--')) ||
      {'-t', '--target', '--machine', '--no-machine'}
          .contains(arg.split('=').first))) {
    stderr.writeln(
        'Quds controls the generated target and machine protocol. Use a .quds entry point.');
    exitCode = 64;
    return;
  }
  final modes = arguments
      .where((arg) => {'--debug', '--profile', '--release'}.contains(arg))
      .toSet();
  if (modes.length > 1) {
    stderr.writeln('Choose one of --debug, --profile or --release.');
    exitCode = 64;
    return;
  }
  final live = !arguments.contains('--release') &&
      !arguments.contains('--profile') &&
      !arguments.contains('--no-hot');
  final flutter = _flutterExecutable();
  if (flutter == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final actionLabel = buildTarget == null
      ? 'Flutter run${arguments.isEmpty ? '' : ' (${arguments.join(' ')})'}'
      : 'Flutter build $buildTarget${arguments.isEmpty ? '' : ' (${arguments.join(' ')})'}';
  stdout.writeln('Quds: preparing $actionLabel...');
  final prepared = _prepareFlutter(
    input,
    targetPlatform: _flutterPlatform(arguments, buildTarget: buildTarget),
    onProgress: stdout.writeln,
  );
  final root = prepared.root;
  final relative = prepared.relative;
  final build = prepared.build;
  final snapshot = prepared.snapshot;
  final initialSnapshot = snapshot();
  if (!build()) {
    exitCode = prepared.failureCode();
    return;
  }
  stdout.writeln('Built $relative');
  final launchArgs = [
    if (buildTarget == null) 'run' else ...['build', buildTarget],
    '-t',
    relative,
    ...arguments,
  ];
  stdout.writeln('Quds: launching flutter ${launchArgs.join(' ')}...');
  if (!live || buildTarget != null) {
    final process = await Process.start(flutter, launchArgs,
        workingDirectory: root.path,
        environment: desktopLaunchEnvironment(Platform.environment),
        includeParentEnvironment: false,
        mode: ProcessStartMode.inheritStdio);
    exitCode = await process.exitCode;
    return;
  }
  final process = await Process.start(
    flutter,
    ['run', '--machine', '-t', relative, ...arguments],
    workingDirectory: root.path,
    environment: desktopLaunchEnvironment(Platform.environment),
    includeParentEnvironment: false,
  );
  var terminal = stdin.hasTerminal;
  var echo = true;
  var line = true;
  if (terminal) {
    try {
      echo = stdin.echoMode;
      line = stdin.lineMode;
    } on StdinException {
      terminal = false;
    }
  }
  final interrupt = ProcessSignal.sigint
      .watch()
      .listen((_) => process.kill(ProcessSignal.sigint));
  try {
    if (terminal) {
      stdin.echoMode = false;
      stdin.lineMode = false;
    }
    exitCode = await FlutterLiveSession(
            process: process,
            snapshot: snapshot,
            build: build,
            input: stdin,
            initialSnapshot: initialSnapshot)
        .run();
  } finally {
    await interrupt.cancel();
    if (terminal) {
      try {
        stdin.echoMode = echo;
        stdin.lineMode = line;
      } on StdinException {
        // The controlling terminal can close before raw mode is restored.
      }
    }
  }
}

/// Renames generated `main` and reports an escaped error on the Quds line.
///
/// The new `main` is appended, so the lines already recorded in [sourceMap]
/// stay where they are.
String _guardGeneratedMain(String dart, String sourceMap, String suffix) {
  const ignore = '// ignore_for_file: type=lint\n';
  if (!dart.contains(ignore)) return dart;
  final entry = RegExp(r'^(void|Future<void>) main\(([^)]*)\)( async)? \{',
      multiLine: true);
  final match = entry.firstMatch(dart);
  if (match == null) return dart;
  final renamed = dart.replaceFirst(
      entry, '${match[1]} _qMain(${match[2]})${match[3] ?? ''} {');
  final parameters = match[2]!.trim();
  final names = parameters.isEmpty
      ? const <String>[]
      : [
          for (final part in parameters.split(','))
            part.trim().split(RegExp(r'\s+')).last
        ];
  final invoke = names.isEmpty ? '_qMain' : '() => _qMain(${names.join(', ')})';
  final positions = SourcePositions.parse(sourceMap);
  final entries = StringBuffer();
  var first = true;
  for (final entry in positions.byGeneratedLine.entries) {
    if (!first) entries.write(', ');
    first = false;
    final hit = entry.value;
    entries
        .write('${entry.key}: ${jsonEncode('${hit.$1}:${hit.$2}:${hit.$3}')}');
  }
  final withImport = renamed.replaceFirst(
    ignore,
    "import 'dart:async'; // ignore_for_file: type=lint\n",
  );
  final flutter = withImport.contains("package:flutter/");
  final hook = flutter
      ? "FlutterError.onError = (details) { print(details.exceptionAsString()); print(_qMap('\${details.stack}')); }; "
      : '';
  return '''$withImport

const _qLines = <int, String>{$entries};
String _qMap(String stack) {
  final pattern = RegExp(r'([\\w./:+\\-]+\\.dart):(\\d+):(\\d+)');
  return stack.replaceAllMapped(pattern, (match) {
    final path = match[1]!;
    if (!path.endsWith(${jsonEncode(suffix)})) return match[0]!;
    return _qLines[int.parse(match[2]!)] ?? match[0]!;
  });
}

void main(${parameters.isEmpty ? '' : parameters}) {
  $hook runZonedGuarded($invoke, (error, stack) {
    print(error);
    print(_qMap('\$stack'));
  });
}
''';
}

File _flutterGenerated(File input, Directory root) {
  var relative = _relativePosix(root, input.absolute);
  if (relative.endsWith('.quds')) {
    relative = '${relative.substring(0, relative.length - 5)}.dart';
  } else {
    relative = '$relative.dart';
  }
  const libPrefix = 'lib/';
  final under = relative.startsWith(libPrefix)
      ? 'lib/quds_gen/${relative.substring(libPrefix.length)}'
      : 'lib/quds_gen/$relative';
  return File(_join(root.path, under));
}

String _relativeGeneratedUri(Directory from, File to) {
  final left = from.absolute.uri
      .normalizePath()
      .pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  final right = to.absolute.uri
      .normalizePath()
      .pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  var shared = 0;
  while (shared < left.length &&
      shared < right.length &&
      (Platform.isWindows
          ? left[shared].toLowerCase() == right[shared].toLowerCase()
          : left[shared] == right[shared])) shared++;
  return [...List.filled(left.length - shared, '..'), ...right.skip(shared)]
      .map((s) => s == '..' ? s : Uri.encodeComponent(s))
      .join('/');
}

String _relativePosix(Directory root, File file) {
  final rootCanon = _canonicalPathCli(root.path);
  final fileCanon = _canonicalPathCli(file.absolute.path);
  final prefix = rootCanon.endsWith('/') ? rootCanon : '$rootCanon/';
  final matches = Platform.isWindows
      ? fileCanon.toLowerCase().startsWith(prefix.toLowerCase())
      : fileCanon.startsWith(prefix);
  if (matches) return fileCanon.substring(prefix.length);
  return fileCanon;
}

String _join(String root, String relative) {
  final tail = relative.replaceAll('/', Platform.pathSeparator);
  if (root.endsWith(Platform.pathSeparator)) return '$root$tail';
  return '$root${Platform.pathSeparator}$tail';
}

String? _flutterExecutable() {
  final found = commandOnPath('flutter');
  if (found != null) return found;
  final root = Platform.environment['FLUTTER_ROOT'];
  final home = homeDirectory();
  final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final candidates = [
    if (root != null && root.isNotEmpty) '$root/bin/$executable',
    if (home != null && home.isNotEmpty)
      '$home/development/flutter/bin/$executable',
    if (home != null && home.isNotEmpty) '$home/flutter/bin/$executable',
    '/snap/bin/flutter',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

Future<void> _pub(String command, List<String> arguments) async {
  await _pubCommand([command, ...arguments.skip(1)]);
}

Future<void> _flutterCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: quds flutter <arguments>');
    exitCode = 64;
    return;
  }
  final executable = _flutterExecutable();
  if (executable == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final child = await Process.start(executable, arguments,
      mode: ProcessStartMode.inheritStdio);
  exitCode = await child.exitCode;
}

Future<void> _pubCommand(List<String> arguments) async {
  var directory = Directory.current.path;
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if ((arg == '-C' || arg == '--directory') && i + 1 < arguments.length)
      directory = arguments[++i];
    else if (arg.startsWith('-C') && arg.length > 2)
      directory = arg.substring(2);
    else if (arg.startsWith('--directory=')) directory = arg.substring(12);
  }
  final flutter = _flutterPackage(File('$directory/_pub.quds'));
  final executable = flutter ? _flutterExecutable() : _dartExecutable();
  if (executable == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final result = await Process.start(executable, ['pub', ...arguments],
      mode: ProcessStartMode.inheritStdio);
  exitCode = await result.exitCode;
}

void _doc(List<String> arguments) {
  final testing = arguments.length >= 2 && arguments[1] == 'test';
  final html = arguments.length >= 2 && arguments[1] == 'html';
  if (testing || html) {
    final path = arguments.length >= 3 ? arguments[2] : null;
    final destination = html && arguments.length == 4 ? arguments[3] : null;
    if (path == null ||
        !path.endsWith('.quds') ||
        (html && (destination == null || !destination.endsWith('.html')))) {
      stderr.writeln(testing
          ? 'Usage: quds doc test <input.quds>'
          : 'Usage: quds doc html <input.quds> <output.html>');
      exitCode = 64;
      return;
    }
    final input = File(path);
    try {
      if (testing) {
        _docTest(input);
      } else {
        _docHtml(input, File(destination!));
      }
    } on CompilerException catch (error) {
      _reportCompilerError(error);
      exitCode = 65;
    } on FileSystemException catch (error) {
      stderr.writeln(error.message);
      exitCode = 74;
    }
    return;
  }

  String? outputPath;
  String? target;
  for (var i = 1; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '-o' || arg == '--output') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('Missing value for $arg');
        exitCode = 64;
        return;
      }
      outputPath = arguments[++i];
    } else if (arg.startsWith('--output=')) {
      outputPath = arg.substring('--output='.length);
    } else if (arg.startsWith('-')) {
      stderr.writeln('Unknown option for doc: $arg');
      exitCode = 64;
      return;
    } else if (target == null) {
      target = arg;
    } else {
      stderr.writeln('Usage: quds doc [-o/--output <path>] <input.quds|dir>');
      exitCode = 64;
      return;
    }
  }
  target ??= Directory('lib').existsSync() ? 'lib' : '.';
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.notFound) {
    stderr.writeln('Cannot open file: $target');
    exitCode = 74;
    return;
  }
  try {
    if (type == FileSystemEntityType.file) {
      if (!target.endsWith('.quds')) {
        stderr.writeln('Usage: quds doc [-o/--output <path>] <input.quds|dir>');
        exitCode = 64;
        return;
      }
      final input = File(target);
      if (outputPath != null) {
        _docHtml(input, File(outputPath));
        return;
      }
      _printFileDocs(input);
      return;
    }
    final files = <File>[];
    _collectQudsFiles(Directory(target), files, <String>{});
    files.sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      stdout.writeln('No .quds files found.');
      return;
    }
    if (outputPath != null) {
      final outDir = Directory(outputPath)..createSync(recursive: true);
      final base = Directory(target).absolute.uri.normalizePath().toFilePath();
      final prefix = base.endsWith(Platform.pathSeparator)
          ? base
          : '$base${Platform.pathSeparator}';
      for (final file in files) {
        var rel = file.absolute.uri.normalizePath().toFilePath();
        if (rel.startsWith(prefix)) rel = rel.substring(prefix.length);
        final htmlRel = rel.endsWith('.quds')
            ? '${rel.substring(0, rel.length - 5)}.html'
            : '$rel.html';
        _docHtml(file, File('${outDir.path}${Platform.pathSeparator}$htmlRel'));
      }
      return;
    }
    for (final file in files) {
      _printFileDocs(file);
    }
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
}

void _printFileDocs(File input) {
  final lines = input.readAsLinesSync();
  final docs = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].trimLeft().startsWith('///')) continue;
    final comment = lines[i].trimLeft().substring(3).trim();
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    docs.add(next.isEmpty ? comment : '$next — $comment');
  }
  stdout.write(docs.isEmpty ? '' : '${docs.join('\n')}\n');
}

void _docHtml(File input, File output) {
  final lines = input.readAsLinesSync();
  final title = _escape(input.uri.pathSegments.last);
  final buffer = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html><head><meta charset="utf-8"><title>$title</title></head>')
    ..writeln('<body>')
    ..writeln('<h1>$title</h1>');
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].trimLeft().startsWith('///')) continue;
    final comment = lines[i].trimLeft().substring(3).trim();
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    if (next.isNotEmpty && !next.startsWith('///')) {
      buffer.writeln('<h2>${_escape(next)}</h2>');
    }
    buffer.writeln('<p>${_escape(comment)}</p>');
  }
  buffer.writeln('</body></html>');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote ${output.path}');
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

void _benchmark(List<String> arguments) {
  const usage =
      'Usage: quds benchmark <input.quds> [--baseline <microseconds>] '
      '[--measure] [--warmup <count>] [--repeat <count>]';
  final args = [...arguments];
  final measured = args.remove('--measure');
  int? option(String name, int? fallback) {
    final index = args.indexOf(name);
    if (index == -1) return fallback;
    if (index + 1 >= args.length) throw FormatException(usage);
    final value = int.tryParse(args[index + 1]);
    if (value == null || value < 0)
      throw FormatException('$name must be a nonnegative integer');
    args.removeRange(index, index + 2);
    return value;
  }

  try {
    final baseline = option('--baseline', null);
    final warmup = option('--warmup', 1)!;
    final repeat = option('--repeat', 5)!;
    if (repeat < 1 ||
        repeat > 100 ||
        warmup > 100 ||
        args.length != 2 ||
        !args[1].endsWith('.quds')) {
      throw FormatException(usage);
    }
    final input = File(args[1]);
    final source = input.readAsStringSync();
    final total = Stopwatch()..start();
    final compileWatch = Stopwatch()..start();
    final result = compile(source, file: input.path);
    compileWatch.stop();
    final directory = Directory.systemTemp.createTempSync('quds-bench-');
    try {
      final stageWatch = Stopwatch()..start();
      final (dart, staged) = _temporaryDartTree(input, result, directory);
      stageWatch.stop();
      final debug = Process.runSync(_dartExecutable(),
          _withPackages(['run', '--enable-asserts', dart.path], input: input));
      final release = Process.runSync(
          _dartExecutable(),
          _withPackages(['run', '--no-enable-asserts', dart.path],
              input: input));
      if (debug.exitCode != 0 || release.exitCode != 0) {
        stderr.write(_atQuds(
            debug.exitCode != 0 ? debug.stderr : release.stderr,
            staged.sourceMap,
            dart.uri.pathSegments.last));
        exitCode = debug.exitCode != 0 ? debug.exitCode : release.exitCode;
        return;
      }
      if (debug.stdout != release.stdout) {
        stderr.writeln('Debug/release output differs');
        exitCode = 1;
        return;
      }
      stdout.writeln('parity ok');
      if (measured) {
        final compilerSamples = <int>[];
        for (var i = 0; i < warmup + repeat; i++) {
          final watch = Stopwatch()..start();
          final next = compile(source, file: input.path);
          watch.stop();
          if (next.dart != result.dart)
            throw StateError('Compiler output changed during measurement');
          if (i >= warmup) compilerSamples.add(watch.elapsedMicroseconds);
        }
        final binary =
            '${directory.path}/bench${Platform.isWindows ? '.exe' : ''}';
        final aotWatch = Stopwatch()..start();
        final aot = Process.runSync(_dartExecutable(), [
          'compile',
          'exe',
          if (_packageConfigPath() case final config?) '--packages=$config',
          dart.path,
          '-o',
          binary
        ]);
        aotWatch.stop();
        if (aot.exitCode != 0) {
          stderr.write(_atQuds(
              aot.stderr, staged.sourceMap, dart.uri.pathSegments.last));
          exitCode = aot.exitCode;
          return;
        }
        final runtimeSamples = <int>[];
        for (var i = 0; i < warmup + repeat; i++) {
          final watch = Stopwatch()..start();
          final run = Process.runSync(binary, const []);
          watch.stop();
          if (run.exitCode != 0 || run.stdout != debug.stdout) {
            stderr.writeln('Measured AOT execution failed or output differs');
            stderr.write(run.stderr);
            exitCode = run.exitCode == 0 ? 1 : run.exitCode;
            return;
          }
          if (i >= warmup) runtimeSamples.add(watch.elapsedMicroseconds);
        }
        Map<String, Object> samples(List<int> values) {
          final sorted = [...values]..sort();
          return {
            'samples_us': values,
            'min_us': sorted.first,
            'median_us': sorted[sorted.length ~/ 2],
            'max_us': sorted.last
          };
        }

        final version = Process.runSync(_dartExecutable(), ['--version']);
        stdout.writeln('metrics ${jsonEncode({
              'schema': 1,
              'input': input.path,
              'source_bytes': utf8.encode(source).length,
              'dart_bytes': utf8.encode(staged.dart).length,
              'dart': '${version.stdout}${version.stderr}'.trim(),
              'os': Platform.operatingSystem,
              'processors': Platform.numberOfProcessors,
              'warmup': warmup,
              'repeat': repeat,
              'initial_quds_compile_us': compileWatch.elapsedMicroseconds,
              'module_staging_us': stageWatch.elapsedMicroseconds,
              'warm_quds_compile': samples(compilerSamples),
              'dart_aot_compile_us': aotWatch.elapsedMicroseconds,
              'aot_process_execution_including_startup':
                  samples(runtimeSamples),
              'output': '${debug.stdout}',
            })}');
      }
      total.stop();
      final elapsed = total.elapsedMicroseconds;
      stdout.writeln('elapsed $elapsed');
      if (baseline != null && elapsed > baseline) {
        stderr.writeln('Benchmark regression: $elapsed > $baseline');
        exitCode = 1;
      }
    } finally {
      directory.deleteSync(recursive: true);
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on CompilerException catch (error) {
    _reportCompilerError(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  } on ProcessException catch (error) {
    stderr.writeln(error.message);
    exitCode = 69;
  }
}

void _docTest(File input) {
  final source = input.readAsStringSync();
  final program = Parser(Lexer().tokenize(source, file: input.path)).parse();
  final names = <String>{
    for (final statement in program.statements)
      if (statement is FunctionDeclaration) statement.name,
    for (final statement in program.statements)
      if (statement is ClassDeclaration) statement.name,
  };
  final lines = source.split('\n');
  final examples = <String>[];
  final fence = StringBuffer();
  var inFence = false;
  final link = RegExp(r'\[([A-Za-z_][A-Za-z0-9_]*)\](?!\()');
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('///')) continue;
    var body = trimmed.substring(3);
    if (body.startsWith(' ')) body = body.substring(1);
    if (body.startsWith('```')) {
      if (inFence) {
        examples.add(fence.toString());
        fence.clear();
        inFence = false;
      } else {
        inFence = true;
      }
      continue;
    }
    if (inFence) {
      fence.writeln(body);
      continue;
    }
    final found = link.firstMatch(body);
    if (found != null && !names.contains(found.group(1))) {
      throw CompilerException('E200', 'Broken link: ${found.group(1)}',
          SourceSpan(1, 1, 0, file: input.path));
    }
  }
  if (inFence) {
    throw CompilerException('E100', 'A doctest fence is not closed',
        SourceSpan(1, 1, 0, file: input.path));
  }
  for (final example in examples) {
    final directory = Directory.systemTemp.createTempSync('quds-doc-');
    try {
      final compiled = compile(example, file: input.path);
      writeSdkBundles(directory.path, compiled);
      final output = File('${directory.path}/doc.dart')
        ..writeAsStringSync(compiled.dart);
      final run = Process.runSync(
          _dartExecutable(), _withPackages([output.path], input: input));
      if (run.exitCode != 0) {
        stderr.write(run.stdout);
        stderr.write(run.stderr);
        exitCode = 65;
        return;
      }
    } on CompilerException catch (error) {
      _reportCompilerError(error);
      exitCode = 65;
      return;
    } finally {
      directory.deleteSync(recursive: true);
    }
  }
}

Future<void> _migrate(List<String> arguments) async {
  // Keep explicit `quds migrate <path/to/quds.yaml>` language-version migration.
  if (arguments.length == 2 &&
      !arguments[1].startsWith('-') &&
      (arguments[1].endsWith('.yaml') || arguments[1].endsWith('.yml'))) {
    _migrateQudsYaml(arguments[1]);
    return;
  }

  final workerOverride = Platform.environment['QUDS_MIGRATE_WORKER'];
  final Uri? worker =
      workerOverride != null && File(workerOverride).existsSync()
          ? Uri.file(workerOverride)
          : await _resolvePackageWorker('src/dart_migrate_worker.dart');
  if (worker == null) {
    stderr.writeln('Dart-to-Quds migration worker is unavailable.');
    exitCode = 1;
    return;
  }
  final config = _packageConfigPath();
  final child = await Process.start(
    _dartExecutable(),
    [
      if (config != null && !worker.path.endsWith('.dill'))
        '--packages=$config',
      worker.toFilePath(),
      ...arguments.skip(1),
    ],
    mode: ProcessStartMode.inheritStdio,
  );
  final termination = Platform.isWindows
      ? null
      : ProcessSignal.sigterm.watch().listen((_) => child.kill());
  try {
    exitCode = await child.exitCode;
  } finally {
    await termination?.cancel();
  }
}

void _migrateQudsYaml(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    file.writeAsStringSync('language: 1.2\n');
    stdout.writeln('Migrated $path to language 1.2');
    return;
  }
  final source = file.readAsStringSync();
  final declared =
      RegExp(r'^[ \t]*language:[ \t]*"?([^"\s#]+)"?', multiLine: true)
          .firstMatch(source)
          ?.group(1);
  if (declared != null && declared != '1.2') {
    stdout.writeln('Left $path on language $declared');
    return;
  }
  if (declared == null) {
    file.writeAsStringSync('language: 1.2\n$source');
  }
  stdout.writeln('Migrated $path to language 1.2');
}

/// Proxies the Debug Adapter Protocol to `dart debug_adapter`.
///
/// A `.quds` program is built first. Breakpoints and stopped frames use the
/// `.quds` line. The Dart adapter debugs the generated file.
Future<void> _debug(List<String> arguments) async {
  final translator = DebugTranslator(build: _debugBuild);
  final target = arguments.length >= 2 ? arguments[1] : null;
  final flutter = target != null && _flutterPackage(File(target));
  final executable = flutter ? _flutterExecutable() : _dartExecutable();
  if (executable == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final child = await Process.start(
    executable,
    [flutter ? 'debug-adapter' : 'debug_adapter'],
    environment:
        flutter ? desktopLaunchEnvironment(Platform.environment) : null,
    includeParentEnvironment: !flutter,
    mode: ProcessStartMode.normal,
  );
  child.stderr.listen(stderr.add);
  var outbound = Future<void>.value();
  void write(Map<String, dynamic> message) {
    outbound = outbound.then((_) async {
      stdout.write(encodeFrame(message));
      await stdout.flush();
    });
  }

  var inbound = Future<void>.value();
  FlutterDebugLive? live;
  void toAdapter(Map<String, dynamic> message) {
    inbound = inbound.then((_) async {
      child.stdin.write(encodeFrame(message));
      await child.stdin.flush();
    });
  }

  void console(String message) => write({
        'seq': 0,
        'type': 'event',
        'event': 'output',
        'body': {'category': 'stderr', 'output': '$message\n'}
      });
  final fromAdapter = _readFrames(child.stdout).listen((message) {
    if (live?.adapterMessage(message) == false) return;
    if (translator.shouldPresent(message)) write(translator.present(message));
  });
  final fromEditor = _readFrames(stdin).listen((message) {
    if (flutter &&
        message['type'] == 'request' &&
        live?.request(message) == true) return;
    String? baseline;
    _FlutterPreparation? prepared;
    if (flutter && message['command'] == 'launch') {
      final config = message['arguments'] as Map?;
      final program = config?['program'];
      final options = config?['toolArgs'] as List? ?? const [];
      final mode = config?['flutterMode'];
      if (program is String && program.endsWith('.quds')) {
        final input = File(program).absolute;
        prepared = _prepareFlutter(input,
            guardMain: false,
            targetPlatform: _flutterPlatform(
                options.map((value) => '$value').toList(),
                device: config?['deviceId'] as String?));
        _debugFlutterGraphs[input.path] = prepared;
        if (mode != 'release' &&
            mode != 'profile' &&
            !options.any((value) =>
                {'--release', '--profile', '--no-hot'}.contains(value))) {
          baseline = prepared.snapshot();
        }
      }
    }
    final action = translator.accept(message);
    if (action.reply != null) write(action.reply!);
    void refreshMaps(_FlutterPreparation graph) {
      for (final path in graph.files()) {
        final generated =
            _flutterGenerated(File(path), _packageRoot(File(path).parent));
        final map = File('${generated.path}.map');
        translator.bind(DebugBinary(path, generated.path,
            map.existsSync() ? map.readAsStringSync() : '',
            cwd: graph.root.path));
      }
    }

    if (action.message != null) {
      if (prepared != null) refreshMaps(prepared);
      if (prepared != null && baseline != null) {
        live?.dispose();
        final graph = prepared;
        live = FlutterDebugLive(
            snapshot: graph.snapshot,
            build: graph.build,
            initialSnapshot: baseline,
            buildError: graph.error,
            refreshMaps: () => refreshMaps(graph),
            send: (value) {
              if (value['type'] == 'response')
                write(value);
              else
                toAdapter(value);
            },
            output: console);
      }
      toAdapter(action.message!);
    }
  });
  try {
    await Future.any(
        [fromEditor.asFuture<void>(), child.exitCode.then((_) {})]);
    live?.dispose();
    await inbound;
    await outbound;
  } finally {
    live?.dispose();
    child.kill();
    await fromEditor.cancel();
    await fromAdapter.cancel();
  }
}

DebugBinary? _debugBuild(String qudsPath, void Function(String message) fail) {
  final input = File(qudsPath);
  if (!input.existsSync()) {
    fail('No such file: $qudsPath');
    return null;
  }
  final absolute = input.absolute.path;
  if (_flutterPackage(input)) {
    final prepared = _debugFlutterGraphs.putIfAbsent(
        absolute, () => _prepareFlutter(input, guardMain: false));
    if (!prepared.build()) {
      fail(prepared.error() ?? 'Quds could not build $absolute');
      return null;
    }
    final map = File('${prepared.target.path}.map');
    return DebugBinary(absolute, prepared.target.path,
        map.existsSync() ? map.readAsStringSync() : '',
        cwd: prepared.root.path);
  }
  try {
    final result = compile(input.readAsStringSync(), file: absolute);
    final saved = exitCode;
    final flutter = _flutterPackage(input);
    final root = _packageRoot(File(absolute).parent);
    final generated =
        flutter ? _flutterGenerated(input, root) : _outputFile(input);
    exitCode = 0;
    final bool built;
    try {
      built = _writeTree(input, <String>{},
          announce: false, flutter: flutter, initial: result);
    } finally {
      exitCode = saved;
    }
    if (!built) {
      fail('Quds could not build the generated dependency graph for $absolute');
      return null;
    }
    final map = result.sourceMap ?? '';
    return DebugBinary(absolute, generated.path, map,
        cwd: flutter ? root.path : null);
  } on CompilerException catch (error) {
    fail('$error');
    return null;
  }
}

Stream<Map<String, dynamic>> _readFrames(Stream<List<int>> input) async* {
  final buffer = <int>[];
  await for (final chunk in input) {
    buffer.addAll(chunk);
    while (true) {
      final headerEnd = _headerEnd(buffer);
      if (headerEnd < 0) break;
      final header = utf8.decode(buffer.sublist(0, headerEnd));
      final match = RegExp(r'Content-Length: (\d+)').firstMatch(header);
      if (match == null) {
        stderr.writeln('Expected a Content-Length header');
        return;
      }
      final length = int.parse(match.group(1)!);
      final start = headerEnd + 4;
      if (buffer.length < start + length) break;
      final body = utf8.decode(buffer.sublist(start, start + length));
      buffer.removeRange(0, start + length);
      final decoded = jsonDecode(body);
      if (decoded is! Map) continue;
      yield decoded
          .map((key, value) => MapEntry(key.toString(), value as dynamic));
    }
  }
}

Future<void> _serve(LspSession session) async {
  // Notifications can arrive while a response is flushing. IOSink must not
  // be written while it is bound to its flush stream; serialize every frame.
  var writes = Future<void>.value();
  void send(Map<String, dynamic> message) {
    final frame = encodeFrame(message);
    writes = writes.then((_) async {
      stdout.write(frame);
      await stdout.flush();
    });
  }

  session.emit = send;
  final buffer = <int>[];
  await for (final chunk in stdin) {
    buffer.addAll(chunk);
    while (true) {
      final headerEnd = _headerEnd(buffer);
      if (headerEnd < 0) break;
      final header = utf8.decode(buffer.sublist(0, headerEnd));
      final match = RegExp(r'Content-Length: (\d+)').firstMatch(header);
      if (match == null) {
        stderr.writeln('Expected a Content-Length header');
        exitCode = 64;
        return;
      }
      final length = int.parse(match.group(1)!);
      final start = headerEnd + 4;
      if (buffer.length < start + length) break;
      final body = utf8.decode(buffer.sublist(start, start + length));
      buffer.removeRange(0, start + length);
      final decoded = jsonDecode(body);
      if (decoded is! Map) continue;
      final message = decoded
          .map((key, value) => MapEntry(key.toString(), value as dynamic));
      final exchange = session.handle(message);
      final frames = [
        if (exchange.response case final response?) response,
        ...exchange.notifications,
      ];
      for (final frame in frames) {
        send(frame);
      }
      if (frames.isNotEmpty) await writes;
    }
  }
}

int _headerEnd(List<int> buffer) {
  for (var i = 0; i + 3 < buffer.length; i++) {
    if (buffer[i] == 13 &&
        buffer[i + 1] == 10 &&
        buffer[i + 2] == 13 &&
        buffer[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}

Future<Uri?> _resolvePackageWorker(String relativeLibPath) async {
  try {
    final resolved = await Isolate.resolvePackageUri(
        Uri.parse('package:quds/$relativeLibPath'));
    if (resolved != null) return resolved;
  } catch (_) {}
  final config = _packageConfigPath();
  if (config != null) {
    final file = File(config);
    final data = jsonDecode(file.readAsStringSync()) as Map;
    for (final entry in data['packages'] as List) {
      if (entry['name'] == 'quds' || entry['name'] == 'quds_lang') {
        var root = file.uri.resolve(entry['rootUri'] as String);
        if (!root.path.endsWith('/')) {
          root = root.replace(path: '${root.path}/');
        }
        return root
            .resolve(entry['packageUri'] as String? ?? 'lib/')
            .resolve(relativeLibPath);
      }
    }
  }
  final compilerRoot = await _compilerRoot();
  if (compilerRoot != null) {
    final candidate = File(
        '${compilerRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}$relativeLibPath');
    if (candidate.existsSync()) return candidate.uri;
  }
  return null;
}

// Kept out of normal CLI imports: the Dart documentation AST parser is loaded
// only by this optional editor service, never by build/run/pub/create.
Future<void> _docPreviewService() async {
  final config = _packageConfigPath();
  final library = await _resolvePackageWorker('src/dart_doc_worker.dart');
  if (library == null) {
    stderr.writeln('Documentation preview service unavailable.');
    exitCode = 1;
    return;
  }
  final child = await Process.start(_dartExecutable(),
      [if (config != null) '--packages=$config', library.toFilePath()],
      mode: ProcessStartMode.inheritStdio);
  final termination = Platform.isWindows
      ? null
      : ProcessSignal.sigterm.watch().listen((_) => child.kill());
  try {
    exitCode = await child.exitCode;
  } finally {
    await termination?.cancel();
  }
}
