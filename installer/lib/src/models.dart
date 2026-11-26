/// Supported desktop operating systems for the Quds Installer.
enum DesktopOs { windows, macos, linux }

/// Verification status for a single prerequisite, tool, or editor.
enum CheckStatus { ready, warning, missing, optional }

/// Source used to install or activate the Quds CLI.
enum InstallSource { pubDev, localPath }

/// Prerequisite installation action suggested for the user's OS.
class PrerequisiteAction {
  const PrerequisiteAction({
    required this.titleAr,
    required this.titleEn,
    required this.command,
    required this.downloadUrl,
    this.executable,
    this.arguments = const [],
    this.canRunDirectly = false,
  });

  final String titleAr;
  final String titleEn;
  final String command;
  final String downloadUrl;
  final String? executable;
  final List<String> arguments;
  final bool canRunDirectly;
}

/// Result of inspecting a core prerequisite (Dart, Git, Flutter, Quds CLI, PATH).
class SystemCheckItem {
  const SystemCheckItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.status,
    required this.detailAr,
    required this.detailEn,
    this.version,
    this.path,
    this.requiredForQuds = false,
    this.action,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final CheckStatus status;
  final String detailAr;
  final String detailEn;
  final String? version;
  final String? path;
  final bool requiredForQuds;
  final PrerequisiteAction? action;
}

/// Detection result for a supported code editor or IDE.
class EditorStatus {
  const EditorStatus({
    required this.id,
    required this.name,
    required this.category,
    required this.detected,
    required this.extensionInstalled,
    this.extensionVersion,
    this.cliPath,
  });

  final String id;
  final String name;
  final String category; // 'vscode', 'jetbrains', 'claude'
  final bool detected;
  final bool extensionInstalled;
  final String? extensionVersion;
  final String? cliPath;
}

/// Complete snapshot of the user's machine produced by the system analyzer.
class SystemReport {
  const SystemReport({
    required this.os,
    required this.osLabel,
    required this.homeDir,
    required this.pubCacheBin,
    required this.pubCacheBinOnPath,
    required this.dartCheck,
    required this.gitCheck,
    required this.flutterCheck,
    required this.qudsCheck,
    required this.legacyQudsLangActive,
    required this.editors,
    this.detectedLocalRepo,
    required this.scannedAt,
  });

  final DesktopOs os;
  final String osLabel;
  final String homeDir;
  final String pubCacheBin;
  final bool pubCacheBinOnPath;
  final SystemCheckItem dartCheck;
  final SystemCheckItem gitCheck;
  final SystemCheckItem flutterCheck;
  final SystemCheckItem qudsCheck;
  final bool legacyQudsLangActive;
  final List<EditorStatus> editors;
  final String? detectedLocalRepo;
  final DateTime scannedAt;

  List<SystemCheckItem> get coreChecks => [
    dartCheck,
    qudsCheck,
    gitCheck,
    flutterCheck,
  ];

  bool get canInstallQuds => dartCheck.status == CheckStatus.ready;

  int get readyCount =>
      coreChecks.where((c) => c.status == CheckStatus.ready).length;

  int get missingRequiredCount => coreChecks
      .where((c) => c.requiredForQuds && c.status != CheckStatus.ready)
      .length;

  List<EditorStatus> get detectedEditors =>
      editors.where((e) => e.detected).toList();
}

/// User-selected installation configuration from Step 2.
class InstallPlan {
  const InstallPlan({
    required this.source,
    required this.qudsVersion,
    this.localRepoPath,
    required this.addToPath,
    required this.removeLegacyQudsLang,
    required this.installEditorSupport,
    required this.selectedEditorIds,
    required this.runVerification,
  });

  final InstallSource source;
  final String qudsVersion;
  final String? localRepoPath;
  final bool addToPath;
  final bool removeLegacyQudsLang;
  final bool installEditorSupport;
  final Set<String> selectedEditorIds;
  final bool runVerification;
}

enum StepRunState { pending, running, done, warning, failed }

class InstallStepProgress {
  const InstallStepProgress({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.state,
    this.subtitle,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final StepRunState state;
  final String? subtitle;

  InstallStepProgress copyWith({StepRunState? state, String? subtitle}) =>
      InstallStepProgress(
        id: id,
        titleAr: titleAr,
        titleEn: titleEn,
        state: state ?? this.state,
        subtitle: subtitle ?? this.subtitle,
      );
}

enum LogLevel { info, command, success, warning, error }

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
}
