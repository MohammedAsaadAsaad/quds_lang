import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/flutter_project.dart';
import 'package:quds_lang/src/libraries.dart'
    show libraryTarget, resolveLibraryPath;
import 'package:quds_lang/src/walk.dart';
import 'package:quds_lang/src/sdk.dart';
import 'package:quds_lang/src/toolchain.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _usage();
    return;
  }
  switch (arguments.first) {
    case 'build':
      _build(arguments);
    case 'run':
      await _run(arguments);
    case 'analyze':
      _analyze(arguments);
    case 'test':
      _test(arguments);
    case 'format':
      _format(arguments);
    case 'create':
      _create(arguments);
    case 'add':
      _pub('add', arguments);
    case 'remove':
      _pub('remove', arguments);
    case 'get':
      _pub('get', arguments);
    case 'doc':
      _doc(arguments);
    case 'migrate':
      _migrate(arguments);
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
        '    Compile to Dart under .dart_tool/quds/out/. --watch rebuilds when a source changes.\n',
    'run': 'quds run <input.quds>\n'
        '    Run the program. An unchanged file reuses the previous build. A Flutter package is launched with flutter run.\n',
    'analyze': 'quds analyze <input.quds>\n'
        '    Compile and run dart analyze on the generated Dart.\n',
    'test': 'quds test <input.quds>\n'
        '    Run the test declarations in the file.\n',
    'format': 'quds format <input.quds>\n'
        '    Rewrite the file with the Quds formatter.\n',
    'create': 'quds create <name>\n'
        '    Create a directory containing a Quds program.\n'
        'quds create flutter <name>\n'
        '    Create a Flutter app whose program is lib/main.quds.\n',
    'add': 'quds add <package>\n    Forward to dart pub add.\n',
    'remove': 'quds remove <package>\n    Forward to dart pub remove.\n',
    'get': 'quds get\n    Forward to dart pub get.\n',
    'doc': 'quds doc <input.quds>\n'
        '    Print /// documentation.\n'
        'quds doc test <input.quds>\n'
        '    Check documentation examples.\n'
        'quds doc html <input.quds> <output.html>\n'
        '    Write the documentation as HTML.\n',
    'migrate': 'quds migrate [quds.yaml]\n'
        '    Write language: 1.2. A file that names another version is left unchanged.\n',
    'benchmark': 'quds benchmark <input.quds> [--baseline <microseconds>]\n'
        '    Run debug and release, require the same output, and print the elapsed time.\n',
    'lsp': 'quds lsp\n'
        '    Serve the language protocol on standard input and output.\n',
    'debug': 'quds debug <input.quds>\n'
        '    Proxy the debug adapter. A Flutter package uses flutter debug-adapter.\n',
    'help': 'quds help [command]\n'
        '    Show every command, or the usage of one command.\n',
    'doctor': 'quds doctor\n'
        '    Check Dart, the quds command, Flutter, and the editors on this machine.\n',
    'install': 'quds install\n'
        '    Activate the quds command and prepare it for the editors on this machine.\n',
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

List<String> _withPackages(List<String> args) {
  final config = _packageConfigPath();
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
  if (arguments.length != 1) {
    stderr.writeln('Usage: quds install');
    exitCode = 64;
    return;
  }
  final root = await _compilerRoot();
  if (root == null) {
    stderr.writeln('The quds_lang package root was not found.');
    exitCode = 1;
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
  final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:quds_lang/quds_lang.dart'));
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

void _requireQuds(List<String> arguments) {
  if (arguments.length != 2 || !arguments[1].endsWith('.quds')) {
    stderr.writeln('Usage: quds ${arguments.first} <input.quds>');
    exitCode = 64;
  }
}

const _generatedHeader = '// Generated by Quds MVP-0. Do not edit.\n';
final _watched = <String>{};
final _compiledHash = <String, String>{};

void _build(List<String> arguments) {
  final watch = arguments.length > 1 && arguments[1] == '--watch';
  final path = watch
      ? (arguments.length == 3 ? arguments[2] : null)
      : (arguments.length == 2 ? arguments[1] : null);
  if (path == null || !path.endsWith('.quds')) {
    stderr.writeln('Usage: quds build [--watch] <input.quds>');
    exitCode = 64;
    return;
  }
  final input = File(path);
  if (!watch) {
    _writeTree(input, <String>{});
    return;
  }
  _watch(input);
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

bool _writeTree(File input, Set<String> seen) {
  final path = input.absolute.path;
  if (!seen.add(path)) return exitCode == 0;
  try {
    final bytes = input.readAsBytesSync();
    _compiledHash[path] = sha256Hex(bytes);
    final result = compile(utf8.decode(bytes), file: input.path);
    if (!_emitGenerated(input, result)) return false;
    _watched.add(path);
    for (final dependency in result.dependencies) {
      if (!dependency.endsWith('.quds')) continue;
      _watched.add(dependency);
      if (dependency == path) continue;
      if (!_writeTree(File(dependency), seen)) return false;
    }
    return exitCode == 0;
  } on CompilerException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
    return false;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
    return false;
  }
}

bool _emitGenerated(File input, Compilation result,
    {bool announce = true, File? destination}) {
  final output = destination ?? _outputFile(input);
  final existing = output.existsSync() ? output.readAsStringSync() : null;
  if (existing != null && !existing.startsWith(_generatedHeader)) {
    stderr.writeln('Refusing to overwrite non-generated file: ${output.path}');
    exitCode = 73;
    return false;
  }
  _writeModels(input, result);
  writeSdkBundles(output.parent.path, result);
  final paths = {...result.dependencies, input.absolute.path}.toList()..sort();
  final sources = _digestListed(paths, input);
  final outputDigest = sha256Hex(utf8.encode(result.dart));
  final cache = _cacheFile(input);
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
    'sources': sources,
    'output': outputDigest,
    'paths': paths,
    'generated': [for (final model in result.models) model.fileName],
  }));
  if (announce) stdout.writeln('Built ${output.path}');
  return true;
}

/// Generated Dart lives under the package's `.dart_tool/quds/out`, mirroring
/// the source path. A lone file with no package root uses its own directory.
File _outputFile(File input) {
  final absolute = input.absolute;
  final root = _packageRoot(absolute.parent);
  var relative = absolute.path;
  final prefix = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (relative.startsWith(prefix)) relative = relative.substring(prefix.length);
  final dartName = relative.endsWith('.quds')
      ? '${relative.substring(0, relative.length - 5)}.dart'
      : '$relative.dart';
  return File(
      '${root.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}quds${Platform.pathSeparator}out${Platform.pathSeparator}$dartName');
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

File _cacheFile(File input) {
  final name = sha256Hex(utf8.encode(input.absolute.path));
  return File('${input.parent.path}/.dart_tool/quds/cache/$name.json');
}

bool _cacheFresh(File cache, String sources, String output) {
  if (!cache.existsSync()) return false;
  final saved = jsonDecode(cache.readAsStringSync());
  return saved is Map &&
      saved['sources'] == sources &&
      saved['output'] == output;
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
bool _cachedOutput(File input, File output) {
  if (!output.existsSync()) return false;
  final cache = _cacheFile(input);
  if (!cache.existsSync()) return false;
  final saved = jsonDecode(cache.readAsStringSync());
  if (saved is! Map) return false;
  final paths = saved['paths'];
  if (paths is! List || paths.isEmpty) return false;
  final listed = [for (final path in paths) '$path'];
  final digest = _digestListed(listed, input);
  final outputDigest = sha256Hex(utf8.encode(output.readAsStringSync()));
  return saved['sources'] == digest && saved['output'] == outputDigest;
}

File? _ensureOutput(File input) {
  final output = _outputFile(input);
  if (_cachedOutput(input, output) && File('${output.path}.map').existsSync()) {
    return output;
  }
  final result = compile(input.readAsStringSync(), file: input.path);
  if (!_emitGenerated(input, result, announce: false, destination: output)) {
    return null;
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

Future<void> _run(List<String> arguments) async {
  _requireQuds(arguments);
  if (exitCode != 0) return;
  final input = File(arguments[1]);
  try {
    if (_flutterPackage(input)) {
      final result = compile(input.readAsStringSync(), file: input.path);
      await _runFlutter(input, result);
      return;
    }
    final output = _ensureOutput(input);
    if (output == null) return;
    final mapFile = File('${output.path}.map');
    final sourceMap = mapFile.existsSync() ? mapFile.readAsStringSync() : null;
    final generatedName = output.uri.pathSegments.last;
    final qudsSource = input.existsSync() ? input.readAsStringSync() : null;
    final process = await Process.start(
      _dartExecutable(),
      _withPackages([output.path]),
      workingDirectory: _packageRoot(input.absolute.parent).path,
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
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
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
        : compile(File(path).readAsStringSync(), file: path);
    walkAst(compiled.program, (node) {
      if (node is ImportDeclaration && !node.uri.startsWith('quds:')) {
        final target = resolveLibraryPath(path, node.uri);
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
  _requireQuds(arguments);
  if (exitCode != 0) return;
  final input = File(arguments[1]);
  try {
    final result = compile(input.readAsStringSync(), file: input.path);
    final directory = Directory.systemTemp.createTempSync('quds-analyze-');
    try {
      final (output, staged) = _temporaryDartTree(input, result, directory);
      final analysis = Process.runSync(
          _dartExecutable(), _withPackages(['analyze', output.path]));
      _writeQuds(analysis.stdout, analysis.stderr, staged.sourceMap,
          output.uri.pathSegments.last);
      exitCode = analysis.exitCode;
    } finally {
      directory.deleteSync(recursive: true);
    }
  } on CompilerException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
}

void _test(List<String> arguments) {
  _requireQuds(arguments);
  if (exitCode != 0) return;
  final input = File(arguments[1]);
  try {
    final result = compile(input.readAsStringSync(), file: input.path);
    final tests =
        result.program.statements.whereType<TestDeclaration>().toList();
    final legacy = result.program.statements
        .whereType<FunctionDeclaration>()
        .where((function) =>
            (function.name == 'test' || function.name.startsWith('test')) &&
            function.parameters.isEmpty &&
            function.generator.isEmpty)
        .toList();
    bool hasTest(TestDeclaration declaration) =>
        declaration.kind == 'test' ||
        declaration.body.whereType<TestDeclaration>().any(hasTest);
    if (!tests.any(hasTest) && legacy.isEmpty) {
      stderr.writeln('No tests found in ${input.path}');
      exitCode = 1;
      return;
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
      exitCode = 1;
      return;
    }
    final directory = Directory.systemTemp.createTempSync('quds-test-');
    try {
      final (suite, staged) = _temporaryDartTree(input, result, directory);
      suite.writeAsStringSync('${staged.dart}\nFuture<int> $entry() async {\n'
          '$calls\n  return $status;\n}\n');
      final suiteUri = jsonEncode(suite.uri.toString()).replaceAll(r'$', r'\$');
      final output = File('${directory.path}/main.dart')
        ..writeAsStringSync("import 'dart:io' as io;\n"
            'import $suiteUri as suite;\n'
            'Future<void> main() async {\n'
            '  io.exitCode = await suite.$entry();\n}\n');
      final run =
          Process.runSync(_dartExecutable(), _withPackages([output.path]));
      _writeQuds(run.stdout, run.stderr, staged.sourceMap,
          suite.uri.pathSegments.last);
      exitCode = run.exitCode;
    } finally {
      directory.deleteSync(recursive: true);
    }
  } on CompilerException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
}

void _format(List<String> arguments) {
  _requireQuds(arguments);
  if (exitCode != 0) return;
  final input = File(arguments[1]);
  try {
    final source = input.readAsStringSync();
    Parser(Lexer().tokenize(source, file: input.path)).parse();
    input.writeAsStringSync(formatQuds(source));
    stdout.writeln('Formatted ${input.path}');
  } on CompilerException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
}

void _create(List<String> arguments) {
  if (arguments.length >= 2 && arguments[1] == 'flutter') {
    if (arguments.length != 3) {
      stderr.writeln('Usage: quds create flutter <name>');
      exitCode = 64;
      return;
    }
    _createFlutter(arguments[2]);
    return;
  }
  if (arguments.length != 2) {
    stderr.writeln('Usage: quds create <name>');
    stderr.writeln('       quds create flutter <name>');
    exitCode = 64;
    return;
  }
  final name = arguments[1];
  final directory = Directory(name);
  if (directory.existsSync()) {
    stderr.writeln('Directory already exists: $name');
    exitCode = 73;
    return;
  }
  directory.createSync(recursive: true);
  File('$name/quds.yaml').writeAsStringSync('language: 1.2\nname: $name\n');
  File('$name/pubspec.yaml').writeAsStringSync('name: $name\nenvironment:\n'
      '  sdk: ">=3.3.0 <4.0.0"\n');
  File('$name/main.quds').writeAsStringSync('main():\n  print "$name"\n');
  stdout.writeln('Created $name');
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

bool _flutterPackage(File input) {
  final root = _packageRoot(input.absolute.parent);
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  return RegExp(r'^\s*sdk:\s*flutter\s*(?:#.*)?$', multiLine: true)
      .hasMatch(pubspec.readAsStringSync());
}

Future<void> _runFlutter(File input, Compilation result) async {
  final flutter = _flutterExecutable();
  if (flutter == null) {
    stderr.writeln('Flutter was not found. Install Flutter and retry.');
    exitCode = 1;
    return;
  }
  final root = _packageRoot(input.absolute.parent);
  final target = _flutterGenerated(input, root);
  if (target.existsSync() &&
      !target.readAsStringSync().startsWith(_generatedHeader)) {
    stderr.writeln('Refusing to overwrite non-generated file: ${target.path}');
    exitCode = 73;
    return;
  }
  target.parent.createSync(recursive: true);
  final relative = _relativePosix(root, target);
  final suffix = relative.contains('quds_gen/')
      ? relative.substring(relative.indexOf('quds_gen/'))
      : relative;
  final guarded = result.sourceMap == null
      ? result.dart
      : _guardGeneratedMain(result.dart, result.sourceMap!, suffix);
  target.writeAsStringSync(guarded);
  writeSdkBundles(target.parent.path, result);
  if (result.sourceMap != null) {
    File('${target.path}.map').writeAsStringSync(result.sourceMap!);
  }
  stdout.writeln('Built $relative');
  final process = await Process.start(
    flutter,
    ['run', '-t', relative],
    workingDirectory: root.path,
    environment: desktopLaunchEnvironment(Platform.environment),
    includeParentEnvironment: false,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}

/// Renames generated `main` and reports an escaped error on the Quds line.
///
/// The new `main` is appended, so the lines already recorded in [sourceMap]
/// stay where they are.
String _guardGeneratedMain(String dart, String sourceMap, String suffix) {
  const ignore = '// ignore_for_file: type=lint\n';
  if (!dart.contains(ignore)) return dart;
  var renamed =
      dart.replaceFirst('void main() async {', 'void _qMain() async {');
  if (identical(renamed, dart)) {
    renamed = dart.replaceFirst('void main() {', 'void _qMain() {');
  }
  if (identical(renamed, dart)) return dart;
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

void main() {
  $hook runZonedGuarded(_qMain, (error, stack) {
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

String _relativePosix(Directory root, File file) {
  final prefix = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  final path = file.absolute.path;
  final relative =
      path.startsWith(prefix) ? path.substring(prefix.length) : path;
  return relative.replaceAll(Platform.pathSeparator, '/');
}

String _join(String root, String relative) {
  final tail = relative.replaceAll('/', Platform.pathSeparator);
  if (root.endsWith(Platform.pathSeparator)) return '$root$tail';
  return '$root${Platform.pathSeparator}$tail';
}

String? _flutterExecutable() {
  final found = Process.runSync('which', ['flutter']);
  if (found.exitCode == 0) {
    final path = (found.stdout as String).trim();
    if (path.isNotEmpty) return path.split('\n').first;
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  final home = Platform.environment['HOME'];
  final candidates = [
    if (root != null && root.isNotEmpty) '$root/bin/flutter',
    if (home != null && home.isNotEmpty)
      '$home/development/flutter/bin/flutter',
    if (home != null && home.isNotEmpty) '$home/flutter/bin/flutter',
    '/snap/bin/flutter',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

void _pub(String command, List<String> arguments) {
  final args = ['pub', command, ...arguments.skip(1)];
  if (command != 'get' && arguments.length < 2) {
    stderr.writeln('Usage: quds $command <package>');
    exitCode = 64;
    return;
  }
  final result = Process.runSync(_dartExecutable(), args);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}

void _doc(List<String> arguments) {
  final testing = arguments.length >= 2 && arguments[1] == 'test';
  final html = arguments.length >= 2 && arguments[1] == 'html';
  final path = testing || html
      ? (arguments.length >= 3 ? arguments[2] : null)
      : (arguments.length == 2 ? arguments[1] : null);
  final destination = html && arguments.length == 4 ? arguments[3] : null;
  if (path == null ||
      !path.endsWith('.quds') ||
      (html && (destination == null || !destination.endsWith('.html')))) {
    stderr.writeln(testing
        ? 'Usage: quds doc test <input.quds>'
        : html
            ? 'Usage: quds doc html <input.quds> <output.html>'
            : 'Usage: quds doc <input.quds>');
    exitCode = 64;
    return;
  }
  final input = File(path);
  try {
    if (testing) {
      _docTest(input);
      return;
    }
    if (html) {
      _docHtml(input, File(destination!));
      return;
    }
    final lines = input.readAsLinesSync();
    final docs = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].trimLeft().startsWith('///')) continue;
      final comment = lines[i].trimLeft().substring(3).trim();
      final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
      docs.add(next.isEmpty ? comment : '$next — $comment');
    }
    stdout.write(docs.isEmpty ? '' : '${docs.join('\n')}\n');
  } on CompilerException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
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
  final args = [...arguments];
  final baselineFlag = args.indexOf('--baseline');
  int? baseline;
  if (baselineFlag != -1) {
    if (baselineFlag + 1 >= args.length) {
      stderr.writeln(
          'Usage: quds benchmark <input.quds> [--baseline <microseconds>]');
      exitCode = 64;
      return;
    }
    baseline = int.tryParse(args[baselineFlag + 1]);
    if (baseline == null) {
      stderr.writeln('Baseline must be an integer number of microseconds');
      exitCode = 64;
      return;
    }
    args
      ..removeAt(baselineFlag + 1)
      ..removeAt(baselineFlag);
  }
  if (args.length != 2 || !args[1].endsWith('.quds')) {
    stderr.writeln(
        'Usage: quds benchmark <input.quds> [--baseline <microseconds>]');
    exitCode = 64;
    return;
  }
  final input = File(args[1]);
  final watch = Stopwatch()..start();
  try {
    final result = compile(input.readAsStringSync(), file: input.path);
    final directory = Directory.systemTemp.createTempSync('quds-bench-');
    try {
      writeSdkBundles(directory.path, result);
      final dart = File('${directory.path}/bench.dart')
        ..writeAsStringSync(result.dart);
      final debug = Process.runSync(_dartExecutable(),
          _withPackages(['run', '--enable-asserts', dart.path]));
      final release = Process.runSync(_dartExecutable(),
          _withPackages(['run', '--no-enable-asserts', dart.path]));
      watch.stop();
      if (debug.exitCode != 0 || release.exitCode != 0) {
        stderr.write(_atQuds(
          debug.exitCode != 0 ? debug.stderr : release.stderr,
          result.sourceMap,
          'bench.dart',
        ));
        exitCode = debug.exitCode != 0 ? debug.exitCode : release.exitCode;
        return;
      }
      if (debug.stdout != release.stdout) {
        stderr.writeln('Debug/release output differs');
        exitCode = 1;
        return;
      }
      final elapsed = watch.elapsedMicroseconds;
      stdout.writeln('parity ok');
      stdout.writeln('elapsed $elapsed');
      if (baseline != null && elapsed > baseline) {
        stderr.writeln('Benchmark regression: $elapsed > $baseline');
        exitCode = 1;
      }
    } finally {
      directory.deleteSync(recursive: true);
    }
  } on CompilerException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
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
      final run =
          Process.runSync(_dartExecutable(), _withPackages([output.path]));
      if (run.exitCode != 0) {
        stderr.write(run.stdout);
        stderr.write(run.stderr);
        exitCode = 65;
        return;
      }
    } on CompilerException catch (error) {
      stderr.writeln(error);
      exitCode = 65;
      return;
    } finally {
      directory.deleteSync(recursive: true);
    }
  }
}

void _migrate(List<String> arguments) {
  final path = arguments.length == 2 ? arguments[1] : 'quds.yaml';
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
  final fromAdapter = _readFrames(child.stdout).listen((message) {
    write(translator.present(message));
  });
  final fromEditor = _readFrames(stdin).listen((message) {
    final action = translator.accept(message);
    if (action.reply != null) write(action.reply!);
    if (action.message != null) {
      inbound = inbound.then((_) async {
        child.stdin.write(encodeFrame(action.message));
        await child.stdin.flush();
      });
    }
  });
  await fromEditor.asFuture<void>();
  await inbound;
  await outbound;
  child.kill();
  await fromAdapter.cancel();
}

DebugBinary? _debugBuild(String qudsPath, void Function(String message) fail) {
  final input = File(qudsPath);
  if (!input.existsSync()) {
    fail('No such file: $qudsPath');
    return null;
  }
  final absolute = input.absolute.path;
  try {
    final result = compile(input.readAsStringSync(), file: absolute);
    final saved = exitCode;
    final flutter = _flutterPackage(input);
    final root = _packageRoot(File(absolute).parent);
    final generated =
        flutter ? _flutterGenerated(input, root) : _outputFile(input);
    if (!_emitGenerated(input, result,
        announce: false, destination: generated)) {
      fail('Quds could not write the generated Dart for $absolute');
      return null;
    }
    exitCode = saved;
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
  session.emit = (message) {
    stdout.write(encodeFrame(message));
    stdout.flush();
  };
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
        if (exchange.response != null) exchange.response,
        ...exchange.notifications,
      ];
      for (final frame in frames) {
        stdout.write(encodeFrame(frame));
      }
      if (frames.isNotEmpty) await stdout.flush();
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
