import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Activates the `quds` command and installs editor support for this machine.
///
/// VS Code and the editors built on it receive the extension. JetBrains IDEs,
/// including Android Studio, receive the same grammar as a TextMate bundle.
/// Claude Code receives a user skill and a language-server plugin. Writing to
/// a directory the user does not own asks for administrator permission.
Future<int> installToolchain({
  required Directory packageRoot,
  required Directory extensionSource,
  required String extensionId,
  required List<String> extensionFiles,
  required List<int> Function() vsixBytes,
}) async {
  final home = homeDirectory();
  if (home == null) {
    stderr.writeln('HOME is not set, so Quds has nowhere to install.');
    return 1;
  }
  final activated = activateCommand(packageRoot);
  rememberPath(home, pubBin(home));
  final failed = await _installEditors(
    home: home,
    source: extensionSource,
    extensionId: extensionId,
    extensionFiles: extensionFiles,
    vsixBytes: vsixBytes,
  );
  final bundle = _shareEditor(home, extensionSource, extensionFiles);
  _installJetBrains(home, bundle);
  await _installClaude(home, packageRoot, extensionSource);
  if (failed) return 1;
  stdout.writeln('Extension id: $extensionId');
  stdout.writeln('Reload each editor and open a .quds file.');
  return activated ? 0 : 1;
}

/// Status lines for the editors this machine can host.
List<String> editorReport() {
  final lines = <String>[];
  final home = homeDirectory();
  for (final editor in _editors) {
    final present = editor.fallback || _editorPresent(editor);
    if (!present) continue;
    final cli = _findCli(editor.commands);
    if (cli == null) {
      if (editor.fallback || _editorPresent(editor)) {
        lines.add('[note] ${editor.label} command was not found.');
      }
    } else {
      lines.add('[ok] ${editor.label} command ($cli)');
    }
    if (!editor.fallback && !_editorPresent(editor)) continue;
    final installed = home == null
        ? null
        : _installedExtension(
            Directory(_join(home, editor.folder, 'extensions')));
    if (installed == null) {
      lines.add(
          '[note] ${editor.label} extension was not found. Run quds install.');
    } else {
      lines.add('[ok] ${editor.label} extension $installed');
    }
  }
  if (home != null) {
    for (final ide in _jetbrainsConfigs(home)) {
      final xml = File(_join(ide.path, 'options', 'textmate.xml'));
      final ready = xml.existsSync() &&
          xml.readAsStringSync().contains(_join(home, '.quds', 'editor')) &&
          xml.readAsStringSync().contains('"enabled":true');
      lines.add(ready
          ? '[ok] ${ide.label} highlighting'
          : '[note] ${ide.label} was found. Run quds install for Quds highlighting.');
    }
    if (_claudePresent(home)) {
      final skill = File(_join(home, '.claude', 'skills', 'quds', 'SKILL.md'));
      lines.add(skill.existsSync()
          ? '[ok] Claude Code skill'
          : '[note] Claude Code was found. Run quds install.');
    }
  }
  return lines;
}

/// The pub cache `bin` directory for this operating system.
String pubBin(String? home) {
  final separator = Platform.pathSeparator;
  final cache = Platform.environment['PUB_CACHE'];
  if (cache != null && cache.isNotEmpty) return '$cache${separator}bin';
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'] ??
        (home == null ? null : '$home${separator}AppData${separator}Local');
    if (local == null) return 'Pub${separator}Cache${separator}bin';
    return '$local${separator}Pub${separator}Cache${separator}bin';
  }
  if (home == null) return '.pub-cache${separator}bin';
  return '$home$separator.pub-cache${separator}bin';
}

/// The current user's home directory.
String? homeDirectory() {
  if (Platform.isWindows) {
    return Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  }
  return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
}

bool activateCommand(Directory root) {
  final offlineOnly = Platform.environment['QUDS_INSTALL_OFFLINE'] == '1';
  var result = _activate(root, offline: true);
  if (result.exitCode != 0 && !offlineOnly) {
    result = _activate(root, offline: false);
  }
  if (result.exitCode != 0) {
    stdout.writeln('[note] The quds command was not added to the pub cache.');
    final message = '${result.stderr}'.trim();
    if (message.isNotEmpty) stderr.writeln(message.split('\n').first);
    return false;
  }
  stdout.writeln('Activated the quds command.');
  return true;
}

ProcessResult _activate(Directory root, {required bool offline}) {
  // Current Dart does not accept --offline on `pub global activate`.
  // Resolve the path package offline first; activation can reuse its config.
  if (offline) {
    final resolved = Process.runSync(
        Platform.resolvedExecutable, ['pub', 'get', '--offline'],
        workingDirectory: root.path);
    if (resolved.exitCode != 0) return resolved;
  }
  return Process.runSync(Platform.resolvedExecutable, [
    'pub',
    'global',
    'activate',
    '--source',
    'path',
    root.path,
  ]);
}

void rememberPath(String home, String bin) {
  final export = 'export PATH="\$PATH:$bin"';
  final block = '# Quds language CLI\n$export\n';
  for (final name in ['.bashrc', '.profile', '.zshrc']) {
    _ensureBlock(File(_join(home, name)), '# Quds language CLI', block);
  }
  final fishDir = Directory(_join(home, '.config', 'fish'));
  if (fishDir.existsSync() || commandOnPath('fish') != null) {
    _ensureBlock(
      File(_join(fishDir.path, 'config.fish')),
      '# Quds language CLI',
      '# Quds language CLI\nfish_add_path --path $bin\n',
    );
  }
  if (Platform.isWindows) _rememberWindowsPath(bin);
  stdout.writeln('Added $bin to the user PATH.');
}

void _rememberWindowsPath(String bin) {
  final script = '''
\$bin = '${bin.replaceAll("'", "''")}'
\$user = [Environment]::GetEnvironmentVariable('Path', 'User')
if (\$user -split ';' -notcontains \$bin) {
  if ([string]::IsNullOrEmpty(\$user)) { \$next = \$bin } else { \$next = "\$user;\$bin" }
  [Environment]::SetEnvironmentVariable('Path', \$next, 'User')
}
''';
  final result =
      Process.runSync('powershell', ['-NoProfile', '-Command', script]);
  if (result.exitCode == 0) return;
  stdout.writeln('Administrator permission is required to update PATH.');
  Process.runSync('powershell', [
    '-NoProfile',
    '-Command',
    "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-Command','${script.replaceAll("'", "''")}'",
  ]);
}

Future<bool> _installEditors({
  required String home,
  required Directory source,
  required String extensionId,
  required List<String> extensionFiles,
  required List<int> Function() vsixBytes,
}) async {
  final chosen = <({_Editor editor, String? cli})>[];
  for (final editor in _editors) {
    final cli = _findCli(editor.commands);
    if (cli == null && !editor.fallback && !_editorPresent(editor)) continue;
    chosen.add((editor: editor, cli: cli));
  }
  File? vsix;
  if (chosen.any((item) => item.cli != null)) {
    final directory = Directory.systemTemp.createTempSync('quds-vsix-');
    vsix = File(_join(directory.path, 'quds.vsix'))
      ..writeAsBytesSync(vsixBytes());
  }
  var failed = false;
  try {
    for (final item in chosen) {
      if (item.cli != null && vsix != null) {
        final result = _runEditor(
            item.cli!, ['--install-extension', vsix.path, '--force']);
        stdout.write(result.stdout);
        stderr.write(result.stderr);
        final name = item.cli!.split(Platform.pathSeparator).last;
        if (result.exitCode == 0) {
          stdout.writeln('Installed the Quds extension with $name.');
        } else {
          stderr.writeln('$name could not install the extension.');
          failed = true;
        }
      } else {
        final destination = Directory(
            _join(home, item.editor.folder, 'extensions', extensionId));
        _copyExtension(source, destination, extensionFiles);
        stdout.writeln('Copied the Quds extension to ${destination.path}');
      }
      if (item.editor.folder == '.antigravity-ide') {
        final legacy = Directory(_join(home, '.antigravity'));
        if (legacy.existsSync()) {
          final destination =
              Directory(_join(legacy.path, 'extensions', extensionId));
          _copyExtension(source, destination, extensionFiles);
          stdout.writeln('Copied the Quds extension to ${destination.path}');
        }
      }
    }
  } finally {
    final parent = vsix?.parent;
    if (parent != null && parent.existsSync())
      parent.deleteSync(recursive: true);
  }
  return failed;
}

String _shareEditor(
    String home, Directory source, List<String> extensionFiles) {
  final destination = Directory(_join(home, '.quds', 'editor'));
  _copyExtension(source, destination, extensionFiles);
  return destination.path;
}

void _installJetBrains(String home, String bundle) {
  final configs = _jetbrainsConfigs(home);
  if (configs.isEmpty) return;
  for (final ide in configs) {
    final xml = File(_join(ide.path, 'options', 'textmate.xml'));
    if (xml.existsSync()) {
      final backup = File('${xml.path}.bak');
      if (!backup.existsSync()) xml.copySync(backup.path);
    }
    final payload = _bundlePayload(xml, bundle);
    _writeText(
        xml,
        _textmateXml(
            xml.existsSync() ? xml.readAsStringSync() : null, payload));
    stdout.writeln('Registered Quds highlighting in ${ide.label}.');
  }
  stdout.writeln(
      'Highlighting covers .quds files. Quit a JetBrains IDE that is already open, then start it again.');
}

String _bundlePayload(File xml, String bundle) {
  final data = <String, Object?>{'bundles': <String, Object?>{}};
  if (xml.existsSync()) {
    final decoded = _textmateJson(xml.readAsStringSync());
    if (decoded is Map && decoded['bundles'] is Map) {
      data['bundles'] = Map<String, Object?>.from(decoded['bundles'] as Map);
    }
  }
  final bundles = Map<String, Object?>.from(data['bundles']! as Map);
  bundles[bundle] = {'name': 'Quds', 'enabled': true};
  data['bundles'] = bundles;
  return jsonEncode(data);
}

Object? _textmateJson(String xml) {
  final match = RegExp(
    r'<component name="TextMateUserBundlesSettings">(.*?)</component>',
    dotAll: true,
  ).firstMatch(xml);
  if (match == null) return null;
  var body = match.group(1)!.trim();
  const start = '<![CDATA[';
  const end = ']]>';
  if (body.startsWith(start) && body.endsWith(end)) {
    body = body.substring(start.length, body.length - end.length).trim();
  }
  body = body
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

String _textmateXml(String? existing, String payload) {
  final component =
      '<component name="TextMateUserBundlesSettings"><![CDATA[$payload]]></component>';
  if (existing == null || existing.trim().isEmpty) {
    return '<application>\n  $component\n</application>\n';
  }
  final pattern = RegExp(
    r'<component name="TextMateUserBundlesSettings">.*?</component>',
    dotAll: true,
  );
  if (pattern.hasMatch(existing))
    return existing.replaceFirst(pattern, component);
  if (existing.contains('</application>')) {
    return existing.replaceFirst(
        '</application>', '  $component\n</application>');
  }
  return '<application>\n  $component\n</application>\n';
}

Future<void> _installClaude(
    String home, Directory packageRoot, Directory extensionSource) async {
  if (!_claudePresent(home)) return;
  final skillSource =
      File(_join(extensionSource.parent.path, 'claude', 'SKILL.md'));
  final skill = skillSource.existsSync()
      ? skillSource.readAsStringSync()
      : 'Use `quds help` for Quds commands.\n';
  _writeText(File(_join(home, '.claude', 'skills', 'quds', 'SKILL.md')), skill);
  final marketplace = Directory(_join(home, '.quds', 'claude-marketplace'));
  final plugin = Directory(_join(marketplace.path, 'plugins', 'quds'));
  _writeText(
    File(_join(plugin.path, '.claude-plugin', 'plugin.json')),
    '${jsonEncode({
          'name': 'quds',
          'description': 'Quds language server for .quds files',
          'version': '0.0.1',
        })}\n',
  );
  _writeText(
    File(_join(plugin.path, '.lsp.json')),
    '${jsonEncode({
          'quds': {
            'command': Platform.resolvedExecutable,
            'args': [
              'run',
              _join(packageRoot.path, 'bin', 'quds.dart'),
              'lsp',
            ],
            'extensionToLanguage': {'.quds': 'quds'},
            'transport': 'stdio',
          },
        })}\n',
  );
  _writeText(File(_join(plugin.path, 'skills', 'quds', 'SKILL.md')), skill);
  _writeText(
    File(_join(marketplace.path, '.claude-plugin', 'marketplace.json')),
    '${jsonEncode({
          'name': 'quds',
          'owner': {'name': 'Quds'},
          'plugins': [
            {
              'name': 'quds',
              'source': './plugins/quds',
              'description': 'Quds language server',
            },
          ],
        })}\n',
  );
  stdout.writeln(
      'Prepared Claude Code skill at ${home}${Platform.pathSeparator}.claude${Platform.pathSeparator}skills${Platform.pathSeparator}quds');
  final claude = commandOnPath('claude');
  if (claude == null) return;
  final added = await _runBounded(claude, [
    'plugin',
    'marketplace',
    'add',
    marketplace.path,
  ]);
  if (!added) {
    stdout.writeln(
        'Claude Code is installed. Add the Quds plugin with: claude plugin marketplace add ${marketplace.path}');
    return;
  }
  final installed = await _runBounded(claude, [
    'plugin',
    'install',
    'quds',
    '--marketplace',
    marketplace.path,
    '--scope',
    'user',
  ]);
  if (installed) {
    stdout.writeln('Installed the Quds language server for Claude Code.');
  } else {
    stdout.writeln(
        'The Claude Code plugin files are in place. Finish with: claude plugin install quds --marketplace ${marketplace.path} --scope user');
  }
}

bool _claudePresent(String home) {
  if (commandOnPath('claude') != null) return true;
  return Directory(_join(home, '.claude')).existsSync();
}

Future<bool> _runBounded(String executable, List<String> arguments) async {
  try {
    final process = await Process.start(executable, arguments);
    final out = StringBuffer();
    final err = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .listen(out.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(err.write)
        .asFuture<void>();
    final code = await process.exitCode.timeout(const Duration(seconds: 20),
        onTimeout: () {
      process.kill();
      return -1;
    });
    await stdoutDone;
    await stderrDone;
    stdout.write(out);
    stderr.write(err);
    return code == 0;
  } on ProcessException {
    return false;
  } on TimeoutException {
    return false;
  }
}

void _copyExtension(
    Directory source, Directory destination, List<String> names) {
  if (destination.existsSync()) {
    try {
      destination.deleteSync(recursive: true);
    } on FileSystemException {
      _elevate(['rm', '-rf', destination.path]);
    }
  }
  for (final name in names) {
    final from = File(_joinAll([source.path, ...name.split('/')]));
    final to = File(_joinAll([destination.path, ...name.split('/')]));
    _copyFile(from, to);
  }
}

void _copyFile(File from, File to) {
  try {
    to.parent.createSync(recursive: true);
    from.copySync(to.path);
  } on FileSystemException {
    stdout.writeln('Administrator permission is required to write ${to.path}.');
    final temp = Directory.systemTemp.createTempSync('quds-copy-');
    final staged = File(_join(temp.path, 'file'));
    from.copySync(staged.path);
    _elevate(['mkdir', '-p', to.parent.path]);
    _elevate(['cp', staged.path, to.path]);
    temp.deleteSync(recursive: true);
  }
}

void _writeText(File file, String contents) {
  try {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  } on FileSystemException {
    stdout
        .writeln('Administrator permission is required to write ${file.path}.');
    final temp = File(
        '${Directory.systemTemp.createTempSync('quds-write-').path}${Platform.pathSeparator}file');
    temp.writeAsStringSync(contents);
    _elevate(['mkdir', '-p', file.parent.path]);
    _elevate(['cp', temp.path, file.path]);
    temp.parent.deleteSync(recursive: true);
  }
}

void _ensureBlock(File file, String marker, String block) {
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  if (existing.contains(marker)) return;
  final separator = existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
  _writeText(file, '$existing$separator$block');
}

bool _elevate(List<String> arguments) {
  stdout.writeln(
      'Quds needs administrator permission. Enter the password if prompted.');
  if (Platform.isWindows) return false;
  final result = Process.runSync('sudo', arguments);
  stderr.write(result.stderr);
  return result.exitCode == 0;
}

ProcessResult _runEditor(String editor, List<String> arguments) {
  final lower = editor.toLowerCase();
  if (Platform.isWindows &&
      (lower.endsWith('.bat') || lower.endsWith('.cmd'))) {
    return Process.runSync('cmd.exe', ['/c', editor, ...arguments]);
  }
  return Process.runSync(editor, arguments);
}

class _Editor {
  const _Editor(this.label, this.commands, this.folder, this.configs,
      {this.fallback = false});

  final String label;
  final List<String> commands;
  final String folder;
  final List<String> configs;
  final bool fallback;
}

const _editors = [
  _Editor('VS Code', ['code'], '.vscode', ['Code'], fallback: true),
  _Editor('VS Code Insiders', ['code-insiders'], '.vscode-insiders',
      ['Code - Insiders']),
  _Editor('Cursor', ['cursor'], '.cursor', ['Cursor'], fallback: true),
  _Editor('VSCodium', ['codium'], '.vscode-oss', ['VSCodium']),
  _Editor('Windsurf', ['windsurf'], '.windsurf', ['Windsurf']),
  _Editor('Positron', ['positron'], '.positron', ['Positron']),
  _Editor('Trae', ['trae'], '.trae', ['Trae']),
  _Editor('Kiro', ['kiro'], '.kiro', ['Kiro']),
  _Editor('Antigravity IDE', ['antigravity-ide', 'antigravity'],
      '.antigravity-ide', ['Antigravity IDE']),
];

class _Ide {
  const _Ide(this.label, this.path);
  final String label;
  final String path;
}

const _jetbrainsProducts = [
  'AndroidStudio',
  'IntelliJIdea',
  'IdeaIC',
  'PyCharm',
  'PyCharmCE',
  'WebStorm',
  'CLion',
  'GoLand',
  'PhpStorm',
  'Rider',
  'RubyMine',
  'RustRover',
  'DataGrip',
  'DataSpell',
  'Aqua',
];

bool _editorPresent(_Editor editor) {
  final home = homeDirectory();
  if (home == null) return false;
  if (Directory(_join(home, editor.folder)).existsSync()) return true;
  for (final config in _configHomes(home)) {
    for (final name in editor.configs) {
      if (Directory(_join(config, name)).existsSync()) return true;
    }
  }
  return _findCli(editor.commands) != null;
}

List<_Ide> _jetbrainsConfigs(String home) {
  final found = <_Ide>[];
  final seen = <String>{};
  void addTree(Directory parent) {
    if (!parent.existsSync()) return;
    for (final entity in parent.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final bare = name.startsWith('.') ? name.substring(1) : name;
      final product = _jetbrainsProducts.cast<String?>().firstWhere(
            (product) => bare.startsWith(product!),
            orElse: () => null,
          );
      if (product == null || !seen.add(entity.path)) continue;
      found.add(_Ide(_ideLabel(product), entity.path));
    }
  }

  for (final config in _configHomes(home)) {
    addTree(Directory(_join(config, 'Google')));
    addTree(Directory(_join(config, 'JetBrains')));
  }
  addTree(Directory(home));
  return found;
}

String _ideLabel(String product) {
  return switch (product) {
    'AndroidStudio' => 'Android Studio',
    'IntelliJIdea' || 'IdeaIC' => 'IntelliJ IDEA',
    'PyCharm' || 'PyCharmCE' => 'PyCharm',
    'WebStorm' => 'WebStorm',
    'CLion' => 'CLion',
    'GoLand' => 'GoLand',
    'PhpStorm' => 'PhpStorm',
    'Rider' => 'Rider',
    'RubyMine' => 'RubyMine',
    'RustRover' => 'RustRover',
    'DataGrip' => 'DataGrip',
    'DataSpell' => 'DataSpell',
    'Aqua' => 'Aqua',
    _ => product,
  };
}

List<String> _configHomes(String home) {
  if (Platform.isWindows) {
    final roaming = Platform.environment['APPDATA'];
    return [roaming ?? _join(home, 'AppData', 'Roaming')];
  }
  if (Platform.isMacOS) return [_join(home, 'Library', 'Application Support')];
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  if (xdg != null && xdg.isNotEmpty) return [xdg];
  return [_join(home, '.config')];
}

String? _findCli(List<String> commands) {
  for (final name in commands) {
    final onPath = commandOnPath(name);
    if (onPath != null) return onPath;
    for (final candidate in _cliCandidates(name)) {
      if (_isFile(candidate)) return candidate;
    }
  }
  return null;
}

List<String> _cliCandidates(String name) {
  final home = homeDirectory();
  final paths = <String>[];
  void add(String path, {bool system = false}) {
    if (system) {
      final root = Platform.environment['QUDS_INSTALL_ROOT'];
      if (root != null && root.isNotEmpty) {
        paths.add('$root$path');
        return;
      }
    }
    paths.add(path);
  }

  if (home != null) add(_join(home, '.local', 'bin', name));
  if (Platform.isLinux) {
    add('/usr/bin/' + name, system: true);
    add('/usr/local/bin/' + name, system: true);
    add('/snap/bin/' + name, system: true);
    add('/usr/share/code/bin/' + name, system: true);
  } else if (Platform.isMacOS && home != null) {
    final apps = {
      'code': 'Visual Studio Code',
      'code-insiders': 'Visual Studio Code - Insiders',
      'cursor': 'Cursor',
      'codium': 'VSCodium',
      'windsurf': 'Windsurf',
      'positron': 'Positron',
      'trae': 'Trae',
      'kiro': 'Kiro',
      'antigravity-ide': 'Antigravity IDE',
      'antigravity': 'Antigravity IDE',
    };
    final app = apps[name];
    if (app != null) {
      final relative =
          '$app.app${Platform.pathSeparator}Contents${Platform.pathSeparator}Resources${Platform.pathSeparator}app${Platform.pathSeparator}bin${Platform.pathSeparator}$name';
      add('/Applications/$relative', system: true);
      add(_join(home, 'Applications', relative));
    }
  } else if (Platform.isWindows && home != null) {
    final local =
        Platform.environment['LOCALAPPDATA'] ?? _join(home, 'AppData', 'Local');
    final programs = Platform.environment['ProgramFiles'];
    final folders = {
      'code': 'Microsoft VS Code',
      'code-insiders': 'Microsoft VS Code Insiders',
      'cursor': 'cursor',
      'codium': 'VSCodium',
      'windsurf': 'Windsurf',
      'positron': 'Positron',
      'trae': 'Trae',
      'kiro': 'Kiro',
      'antigravity-ide': 'Antigravity IDE',
    };
    final folder = folders[name];
    if (folder != null) {
      add(_join(local, 'Programs', folder, 'bin', '$name.cmd'));
      if (programs != null) {
        add(_join(programs, folder, 'bin', '$name.cmd'), system: true);
      }
    }
  }
  return paths;
}

/// Resolves [name] from `PATH`, including Windows `.exe`, `.bat`, and `.cmd`.
String? commandOnPath(String name) {
  final separator = Platform.isWindows ? ';' : ':';
  final names = Platform.isWindows
      ? ['$name.exe', '$name.bat', '$name.cmd', name]
      : [name];
  for (final dir in (Platform.environment['PATH'] ?? '').split(separator)) {
    if (dir.isEmpty) continue;
    for (final fileName in names) {
      final candidate = dir.endsWith(Platform.pathSeparator)
          ? '$dir$fileName'
          : '$dir${Platform.pathSeparator}$fileName';
      if (_isFile(candidate)) return candidate;
    }
  }
  return null;
}

bool _isFile(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: true);
  return type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory;
}

String? _installedExtension(Directory directory) {
  if (!directory.existsSync()) return null;
  final names = <String>[];
  for (final entity in directory.listSync()) {
    if (entity is! Directory) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.startsWith('quds-lang.quds-')) continue;
    if (!File(_join(entity.path, 'package.json')).existsSync()) continue;
    names.add(name);
  }
  if (names.isEmpty) return null;
  names.sort();
  return names.first;
}

String _join(String first, String second,
        [String? third, String? fourth, String? fifth]) =>
    _joinAll([
      first,
      second,
      if (third != null) third,
      if (fourth != null) fourth,
      if (fifth != null) fifth,
    ]);

String _joinAll(List<String> parts) => parts.join(Platform.pathSeparator);
