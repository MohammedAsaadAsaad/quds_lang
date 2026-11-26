import 'dart:async';
import 'dart:io';

import 'models.dart';

/// Default Quds version targeted on pub.dev by the installer.
const defaultQudsVersion = '0.1.0-alpha.2';

/// Abstraction for launching external processes so tests can simulate any OS.
abstract class CommandRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration timeout = const Duration(seconds: 20),
  });

  Future<int> stream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    required void Function(String line, {required bool isError}) onLine,
  });
}

/// Real process runner backed by `dart:io` [Process].
class SystemCommandRunner implements CommandRunner {
  const SystemCommandRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    ).timeout(
      timeout,
      onTimeout: () => ProcessResult(0, 124, '', 'Timed out after $timeout'),
    );
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    required void Function(String line, {required bool isError}) onLine,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
    final outDone = process.stdout
        .transform(const SystemEncoding().decoder)
        .listen((chunk) {
          for (final line in chunk.split(RegExp(r'\r?\n'))) {
            if (line.trim().isNotEmpty) onLine(line, isError: false);
          }
        })
        .asFuture<void>();
    final errDone = process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((chunk) {
          for (final line in chunk.split(RegExp(r'\r?\n'))) {
            if (line.trim().isNotEmpty) onLine(line, isError: true);
          }
        })
        .asFuture<void>();
    final code = await process.exitCode;
    await Future.wait([outDone, errDone]);
    return code;
  }
}

/// Analyzes the host Windows, macOS, or Linux environment to detect installed
/// prerequisites, missing tools, PATH configuration, and code editors.
class SystemAnalyzer {
  SystemAnalyzer({
    CommandRunner? runner,
    DesktopOs? osOverride,
    Map<String, String>? environmentOverride,
  }) : _runner = runner ?? const SystemCommandRunner(),
       _os = osOverride ?? _detectOs(),
       _env = environmentOverride ?? Platform.environment;

  final CommandRunner _runner;
  final DesktopOs _os;
  final Map<String, String> _env;

  static DesktopOs _detectOs() {
    if (Platform.isWindows) return DesktopOs.windows;
    if (Platform.isMacOS) return DesktopOs.macos;
    return DesktopOs.linux;
  }

  /// Checks whether a parsed semantic version [version] satisfies Quds's
  /// minimum requirement `>=3.3.0 <4.0.0`.
  static bool isDartVersionSupported(String? version) {
    if (version == null) return false;
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version.trim());
    if (match == null) return false;
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    return major == 3 && minor >= 3;
  }

  /// Parses the first `X.Y.Z` semantic version from command output.
  static String? extractSemver(String text) =>
      RegExp(r'\b(\d+\.\d+\.\d+)\b').firstMatch(text)?.group(1);

  /// Returns the recommended prerequisite install command for [toolId] on [os].
  static PrerequisiteAction prerequisiteFor(String toolId, DesktopOs os) {
    switch (toolId) {
      case 'dart':
        return switch (os) {
          DesktopOs.windows => const PrerequisiteAction(
            titleAr: 'تثبيت Dart SDK عبر winget',
            titleEn: 'Install Dart SDK via winget',
            command: 'winget install --id Dart.DartSDK -e',
            downloadUrl: 'https://dart.dev/get-dart',
            executable: 'winget',
            arguments: [
              'install',
              '--id',
              'Dart.DartSDK',
              '-e',
              '--accept-package-agreements',
              '--accept-source-agreements',
            ],
            canRunDirectly: true,
          ),
          DesktopOs.macos => const PrerequisiteAction(
            titleAr: 'تثبيت Dart SDK عبر Homebrew',
            titleEn: 'Install Dart SDK via Homebrew',
            command: 'brew tap dart-lang/dart && brew install dart',
            downloadUrl: 'https://dart.dev/get-dart',
            executable: 'sh',
            arguments: ['-c', 'brew tap dart-lang/dart && brew install dart'],
            canRunDirectly: true,
          ),
          DesktopOs.linux => const PrerequisiteAction(
            titleAr: 'تثبيت Dart SDK من مستودع Google الرسمي',
            titleEn: 'Install Dart SDK from Google APT repo',
            command: 'sudo apt-get update && sudo apt-get install -y apt-transport-https curl gnupg && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg && echo "deb [signed-by=/usr/share/keyrings/dart.gpg arch=\$(dpkg --print-architecture)] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" | sudo tee /etc/apt/sources.list.d/dart_stable.list && sudo apt-get update && sudo apt-get install -y dart',
            downloadUrl: 'https://dart.dev/get-dart',
          ),
        };
      case 'git':
        return switch (os) {
          DesktopOs.windows => const PrerequisiteAction(
            titleAr: 'تثبيت Git عبر winget',
            titleEn: 'Install Git via winget',
            command: 'winget install --id Git.Git -e',
            downloadUrl: 'https://git-scm.com/downloads',
            executable: 'winget',
            arguments: [
              'install',
              '--id',
              'Git.Git',
              '-e',
              '--accept-package-agreements',
              '--accept-source-agreements',
            ],
            canRunDirectly: true,
          ),
          DesktopOs.macos => const PrerequisiteAction(
            titleAr: 'تثبيت أدوات Git عبر Xcode CLT',
            titleEn: 'Install Git via Xcode Command Line Tools',
            command: 'xcode-select --install',
            downloadUrl: 'https://git-scm.com/download/mac',
            executable: 'xcode-select',
            arguments: ['--install'],
            canRunDirectly: true,
          ),
          DesktopOs.linux => const PrerequisiteAction(
            titleAr: 'تثبيت Git عبر apt',
            titleEn: 'Install Git via apt',
            command: 'sudo apt-get update && sudo apt-get install -y git',
            downloadUrl: 'https://git-scm.com/download/linux',
          ),
        };
      case 'flutter':
        return switch (os) {
          DesktopOs.windows => const PrerequisiteAction(
            titleAr: 'دليل تثبيت Flutter لنظام Windows',
            titleEn: 'Flutter Setup Guide for Windows',
            command: 'winget install --id Google.Flutter -e',
            downloadUrl: 'https://docs.flutter.dev/get-started/install/windows',
            executable: 'winget',
            arguments: [
              'install',
              '--id',
              'Google.Flutter',
              '-e',
              '--accept-package-agreements',
              '--accept-source-agreements',
            ],
            canRunDirectly: true,
          ),
          DesktopOs.macos => const PrerequisiteAction(
            titleAr: 'تثبيت Flutter عبر Homebrew',
            titleEn: 'Install Flutter via Homebrew',
            command: 'brew install --cask flutter',
            downloadUrl: 'https://docs.flutter.dev/get-started/install/macos',
            executable: 'brew',
            arguments: ['install', '--cask', 'flutter'],
            canRunDirectly: true,
          ),
          DesktopOs.linux => const PrerequisiteAction(
            titleAr: 'دليل تثبيت Flutter لنظام Linux',
            titleEn: 'Flutter Setup Guide for Linux',
            command: 'sudo snap install flutter --classic',
            downloadUrl: 'https://docs.flutter.dev/get-started/install/linux',
          ),
        };
      default:
        return const PrerequisiteAction(
          titleAr: 'فتح الموقع الرسمي',
          titleEn: 'Open Official Guide',
          command: 'dart pub global activate quds $defaultQudsVersion',
          downloadUrl: 'https://pub.dev/packages/quds',
        );
    }
  }

  /// Opens [url] in the system's default browser without external plugins.
  Future<bool> openUrl(String url) async {
    try {
      final result = switch (_os) {
        DesktopOs.windows => await _runner.run('cmd', [
          '/c',
          'start',
          '',
          url,
        ], runInShell: true),
        DesktopOs.macos => await _runner.run('open', [url]),
        DesktopOs.linux => await _runner.run('xdg-open', [url]),
      };
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Runs a full non-blocking scan of the host environment.
  Future<SystemReport> scan() async {
    final home = _homeDir();
    final pubBin = _pubCacheBin(home);
    final pathOnEnv = _isDirOnPath(pubBin);

    final dartCheck = await _checkDart();
    final gitCheck = await _checkGit();
    final flutterCheck = await _checkFlutter();
    final qudsResult = await _checkQuds(pubBin, dartCheck.path);
    final editors = await _scanEditors(home);
    final localRepo = _detectLocalQudsRepo();

    final osLabel = switch (_os) {
      DesktopOs.windows => 'Windows',
      DesktopOs.macos => 'macOS',
      DesktopOs.linux => 'Linux',
    };

    return SystemReport(
      os: _os,
      osLabel: osLabel,
      homeDir: home,
      pubCacheBin: pubBin,
      pubCacheBinOnPath: pathOnEnv,
      dartCheck: dartCheck,
      gitCheck: gitCheck,
      flutterCheck: flutterCheck,
      qudsCheck: qudsResult.$1,
      legacyQudsLangActive: qudsResult.$2,
      editors: editors,
      detectedLocalRepo: localRepo,
      scannedAt: DateTime.now(),
    );
  }

  String _homeDir() {
    if (_os == DesktopOs.windows) {
      return _env['USERPROFILE'] ?? _env['HOME'] ?? r'C:\Users\Public';
    }
    return _env['HOME'] ?? _env['USERPROFILE'] ?? '/tmp';
  }

  String _pubCacheBin(String home) {
    final sep = _os == DesktopOs.windows ? r'\' : '/';
    final custom = _env['PUB_CACHE'];
    if (custom != null && custom.isNotEmpty) {
      return '$custom${sep}bin';
    }
    if (_os == DesktopOs.windows) {
      final local = _env['LOCALAPPDATA'] ?? '$home${sep}AppData${sep}Local';
      return '$local${sep}Pub${sep}Cache${sep}bin';
    }
    return '$home$sep.pub-cache${sep}bin';
  }

  bool _isDirOnPath(String dir) {
    final rawPath = _env['PATH'] ?? _env['Path'] ?? '';
    final sep = _os == DesktopOs.windows ? ';' : ':';
    String norm(String p) => p
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '')
        .toLowerCase();
    final target = norm(dir);
    return rawPath.split(sep).any((entry) => norm(entry) == target);
  }

  String? _findCommand(
    List<String> names, {
    List<String> extraDirs = const [],
  }) {
    final rawPath = _env['PATH'] ?? _env['Path'] ?? '';
    final sep = _os == DesktopOs.windows ? ';' : ':';
    final pathSep = _os == DesktopOs.windows ? r'\' : '/';
    final dirs = [
      ...rawPath.split(sep).where((d) => d.trim().isNotEmpty),
      ...extraDirs,
    ];
    final suffixes = _os == DesktopOs.windows
        ? const ['', '.exe', '.bat', '.cmd']
        : const [''];
    for (final dir in dirs) {
      final cleanDir = dir.trim().replaceAll('"', '');
      for (final name in names) {
        for (final ext in suffixes) {
          final candidate = '$cleanDir$pathSep$name$ext';
          if (File(candidate).existsSync()) return candidate;
        }
      }
    }
    return null;
  }

  Future<SystemCheckItem> _checkDart() async {
    final extra = _os == DesktopOs.windows
        ? [
            r'C:\tools\dart-sdk\bin',
            r'C:\src\flutter\bin\cache\dart-sdk\bin',
            '${_homeDir()}\\flutter\\bin\\cache\\dart-sdk\\bin',
          ]
        : [
            '/opt/flutter/bin/cache/dart-sdk/bin',
            '/usr/lib/dart/bin',
            '/opt/homebrew/bin',
            '/usr/local/bin',
            '${_homeDir()}/flutter/bin/cache/dart-sdk/bin',
          ];
    final exe = _findCommand(['dart'], extraDirs: extra);
    if (exe == null) {
      return SystemCheckItem(
        id: 'dart',
        nameAr: 'حزمة Dart SDK',
        nameEn: 'Dart SDK',
        status: CheckStatus.missing,
        detailAr: 'مطلوب Dart 3.3.0 أو أحدث لتشغيل مترجم لغة قدس.',
        detailEn: 'Dart 3.3.0 or newer is required to run the Quds compiler.',
        requiredForQuds: true,
        action: prerequisiteFor('dart', _os),
      );
    }
    try {
      final res = await _runner.run(exe, ['--version']);
      final combined = '${res.stdout} ${res.stderr}'.trim();
      final ver = extractSemver(combined);
      if (isDartVersionSupported(ver)) {
        return SystemCheckItem(
          id: 'dart',
          nameAr: 'حزمة Dart SDK',
          nameEn: 'Dart SDK',
          status: CheckStatus.ready,
          version: ver,
          path: exe,
          detailAr: 'الإصدار $ver متوافق تماماً مع لغة قدس.',
          detailEn: 'Version $ver is fully compatible with Quds.',
          requiredForQuds: true,
        );
      }
      return SystemCheckItem(
        id: 'dart',
        nameAr: 'حزمة Dart SDK',
        nameEn: 'Dart SDK',
        status: CheckStatus.warning,
        version: ver,
        path: exe,
        detailAr:
            'الإصدار الموجود (${ver ?? 'غير معروف'}) أقدم من 3.3.0. يلزم التحديث قبل التثبيت.',
        detailEn:
            'Found version (${ver ?? 'unknown'}) is older than 3.3.0. Please upgrade first.',
        requiredForQuds: true,
        action: prerequisiteFor('dart', _os),
      );
    } catch (_) {
      return SystemCheckItem(
        id: 'dart',
        nameAr: 'حزمة Dart SDK',
        nameEn: 'Dart SDK',
        status: CheckStatus.missing,
        detailAr: 'تعذر تشغيل dart. يرجى تثبيت Dart SDK 3.3+.',
        detailEn: 'Could not execute dart. Please install Dart SDK 3.3+.',
        requiredForQuds: true,
        action: prerequisiteFor('dart', _os),
      );
    }
  }

  Future<SystemCheckItem> _checkGit() async {
    final exe = _findCommand(['git']);
    if (exe == null) {
      return SystemCheckItem(
        id: 'git',
        nameAr: 'أداة Git',
        nameEn: 'Git',
        status: CheckStatus.warning,
        detailAr: 'موصى به لاعتماديات حزم Git والتحديث من GitHub.',
        detailEn: 'Recommended for Git package dependencies and updates.',
        action: prerequisiteFor('git', _os),
      );
    }
    try {
      final res = await _runner.run(exe, ['--version']);
      final ver = extractSemver('${res.stdout} ${res.stderr}');
      return SystemCheckItem(
        id: 'git',
        nameAr: 'أداة Git',
        nameEn: 'Git',
        status: CheckStatus.ready,
        version: ver,
        path: exe,
        detailAr: 'مثبّت وجاهز (${ver ?? 'Git'}).',
        detailEn: 'Installed and ready (${ver ?? 'Git'}).',
      );
    } catch (_) {
      return SystemCheckItem(
        id: 'git',
        nameAr: 'أداة Git',
        nameEn: 'Git',
        status: CheckStatus.warning,
        detailAr: 'لم يستجب git؛ يُنصح بإعادة تثبيته.',
        detailEn: 'git did not respond; reinstalling is recommended.',
        action: prerequisiteFor('git', _os),
      );
    }
  }

  Future<SystemCheckItem> _checkFlutter() async {
    final extra = _os == DesktopOs.windows
        ? [r'C:\src\flutter\bin', '${_homeDir()}\\flutter\\bin']
        : [
            '/opt/flutter/bin',
            '${_homeDir()}/flutter/bin',
            '/opt/homebrew/bin',
          ];
    final exe = _findCommand(['flutter'], extraDirs: extra);
    if (exe == null) {
      return SystemCheckItem(
        id: 'flutter',
        nameAr: 'إطار Flutter SDK (اختياري)',
        nameEn: 'Flutter SDK (Optional)',
        status: CheckStatus.optional,
        detailAr: 'مطلوب فقط عند بناء تطبيقات واجهة رسومية بـ Flutter + قدس.',
        detailEn: 'Only needed if you plan to build Flutter UI apps with Quds.',
        action: prerequisiteFor('flutter', _os),
      );
    }
    String? ver;
    // Fast version check from flutter/version file before spawning flutter CLI.
    try {
      final binDir = File(exe).parent;
      final versionFile = File(
        '${binDir.parent.path}${Platform.pathSeparator}version',
      );
      if (versionFile.existsSync()) {
        ver = extractSemver(versionFile.readAsStringSync());
      }
    } catch (_) {}
    if (ver == null) {
      try {
        final res = await _runner.run(exe, [
          '--version',
        ], timeout: const Duration(seconds: 12));
        ver = extractSemver('${res.stdout} ${res.stderr}');
      } catch (_) {}
    }
    return SystemCheckItem(
      id: 'flutter',
      nameAr: 'إطار Flutter SDK (اختياري)',
      nameEn: 'Flutter SDK (Optional)',
      status: CheckStatus.ready,
      version: ver,
      path: exe,
      detailAr: 'جاهز لتطوير تطبيقات Flutter بلغة قدس (${ver ?? 'Flutter'}).',
      detailEn: 'Ready for Flutter apps written in Quds (${ver ?? 'Flutter'}).',
    );
  }

  Future<(SystemCheckItem, bool)> _checkQuds(
    String pubBin,
    String? dartExe,
  ) async {
    var legacy = false;
    if (dartExe != null) {
      try {
        final listRes = await _runner.run(dartExe, ['pub', 'global', 'list']);
        final text = '${listRes.stdout}';
        if (RegExp(r'^quds_lang\b', multiLine: true).hasMatch(text)) {
          legacy = true;
        }
      } catch (_) {}
    }

    final exe = _findCommand(['quds'], extraDirs: [pubBin]);
    if (exe == null) {
      return (
        SystemCheckItem(
          id: 'quds',
          nameAr: 'أداة لغة قدس (Quds CLI)',
          nameEn: 'Quds CLI',
          status: CheckStatus.missing,
          detailAr: legacy
              ? 'وُجد تفعيل قديم باسم quds_lang؛ سيستبدله المثبّت بحزمة quds الحديثة.'
              : 'غير مثبّتة بعد — جاهزة للتثبيت الآن.',
          detailEn: legacy
              ? 'Legacy `quds_lang` activation detected; will migrate cleanly to `quds`.'
              : 'Not installed yet — ready to install now.',
        ),
        legacy,
      );
    }

    String? ver;
    try {
      final res = await _runner.run(exe, [
        '--version',
      ], runInShell: _os == DesktopOs.windows);
      final match = RegExp(r'Quds CLI\s+([^\s(]+)').firstMatch('${res.stdout}');
      ver = match?.group(1);
    } catch (_) {}

    final onPath = _isDirOnPath(pubBin) || _findCommand(['quds']) != null;
    if (legacy) {
      return (
        SystemCheckItem(
          id: 'quds',
          nameAr: 'أداة لغة قدس (Quds CLI)',
          nameEn: 'Quds CLI',
          status: CheckStatus.warning,
          version: ver,
          path: exe,
          detailAr:
              'وُجد تفعيل قديم (quds_lang) — سيُحدّث تلقائياً إلى quds $defaultQudsVersion.',
          detailEn:
              'Legacy `quds_lang` detected — will upgrade cleanly to `quds $defaultQudsVersion`.',
        ),
        true,
      );
    }
    return (
      SystemCheckItem(
        id: 'quds',
        nameAr: 'أداة لغة قدس (Quds CLI)',
        nameEn: 'Quds CLI',
        status: onPath ? CheckStatus.ready : CheckStatus.warning,
        version: ver,
        path: exe,
        detailAr: onPath
            ? 'مثبّتة (${ver ?? 'quds'}) ومتاحة في PATH.'
            : 'مثبّتة (${ver ?? 'quds'}) لكن مجلد pub-cache/bin غير مضاف إلى PATH.',
        detailEn: onPath
            ? 'Installed (${ver ?? 'quds'}) and available on PATH.'
            : 'Installed (${ver ?? 'quds'}), but pub-cache/bin is not yet on PATH.',
      ),
      false,
    );
  }

  Future<List<EditorStatus>> _scanEditors(String home) async {
    final sep = _os == DesktopOs.windows ? r'\' : '/';
    String? findExtVersion(String extensionsDir) {
      final dir = Directory(extensionsDir);
      if (!dir.existsSync()) return null;
      try {
        for (final entry in dir.listSync(followLinks: false)) {
          final name = entry.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .toLowerCase();
          if (name.startsWith('quds-lang.quds-')) {
            return name.substring('quds-lang.quds-'.length);
          }
        }
      } catch (_) {}
      return null;
    }

    EditorStatus checkVsFamily({
      required String id,
      required String name,
      required List<String> commands,
      required String dotFolder,
    }) {
      final cli = _findCommand(commands);
      final folderExists = Directory('$home$sep$dotFolder').existsSync();
      final extVer = findExtVersion('$home$sep$dotFolder${sep}extensions');
      return EditorStatus(
        id: id,
        name: name,
        category: 'vscode',
        detected: cli != null || folderExists,
        extensionInstalled: extVer != null,
        extensionVersion: extVer,
        cliPath: cli,
      );
    }

    final editors = <EditorStatus>[
      checkVsFamily(
        id: 'vscode',
        name: 'Visual Studio Code',
        commands: ['code'],
        dotFolder: '.vscode',
      ),
      checkVsFamily(
        id: 'cursor',
        name: 'Cursor',
        commands: ['cursor'],
        dotFolder: '.cursor',
      ),
      checkVsFamily(
        id: 'windsurf',
        name: 'Windsurf',
        commands: ['windsurf'],
        dotFolder: '.windsurf',
      ),
      checkVsFamily(
        id: 'vscodium',
        name: 'VSCodium',
        commands: ['codium'],
        dotFolder: '.vscode-oss',
      ),
      checkVsFamily(
        id: 'vscode-insiders',
        name: 'VS Code Insiders',
        commands: ['code-insiders'],
        dotFolder: '.vscode-insiders',
      ),
    ];

    // JetBrains / Android Studio detection
    final jbRoots = switch (_os) {
      DesktopOs.windows => [
        '${_env['APPDATA'] ?? '$home\\AppData\\Roaming'}\\Google',
        '${_env['APPDATA'] ?? '$home\\AppData\\Roaming'}\\JetBrains',
      ],
      DesktopOs.macos => [
        '$home/Library/Application Support/Google',
        '$home/Library/Application Support/JetBrains',
      ],
      DesktopOs.linux => [
        '${_env['XDG_CONFIG_HOME'] ?? '$home/.config'}/Google',
        '${_env['XDG_CONFIG_HOME'] ?? '$home/.config'}/JetBrains',
      ],
    };
    var jbDetected = false;
    var jbConfigured = false;
    for (final root in jbRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      try {
        for (final child in dir.listSync(followLinks: false)) {
          if (child is! Directory) continue;
          jbDetected = true;
          final tm = File('${child.path}${sep}options${sep}textmate.xml');
          if (tm.existsSync() &&
              tm.readAsStringSync().contains('.quds${sep}editor')) {
            jbConfigured = true;
          }
        }
      } catch (_) {}
    }
    editors.add(
      EditorStatus(
        id: 'jetbrains',
        name: 'Android Studio / JetBrains',
        category: 'jetbrains',
        detected: jbDetected,
        extensionInstalled: jbConfigured,
      ),
    );

    // Claude Code detection
    final claudeCli = _findCommand(['claude']);
    final claudeDir = Directory('$home$sep.claude');
    final claudeSkill = File(
      '$home$sep.claude${sep}skills${sep}quds${sep}SKILL.md',
    );
    editors.add(
      EditorStatus(
        id: 'claude',
        name: 'Claude Code',
        category: 'claude',
        detected: claudeCli != null || claudeDir.existsSync(),
        extensionInstalled: claudeSkill.existsSync(),
        cliPath: claudeCli,
      ),
    );

    return editors;
  }

  String? _detectLocalQudsRepo() {
    var current = Directory.current.absolute;
    for (var i = 0; i < 4; i++) {
      final pubspec = File(
        '${current.path}${Platform.pathSeparator}pubspec.yaml',
      );
      final binQuds = File(
        '${current.path}${Platform.pathSeparator}bin${Platform.pathSeparator}quds.dart',
      );
      if (pubspec.existsSync() && binQuds.existsSync()) {
        final text = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*quds\s*$', multiLine: true).hasMatch(text)) {
          return current.path;
        }
      }
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }
}
