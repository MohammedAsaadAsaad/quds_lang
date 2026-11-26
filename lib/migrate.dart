/// AST-based Dart and Flutter to Quds project migration API.
///
/// Provides feasibility inspection, safe `lib/` backups, single-file Dart to
/// Quds conversion, and full project migration orchestration.
library quds.migrate;

export 'src/dart_migrator.dart'
    show
        DartConversionResult,
        MigratedFileStat,
        MigrationBackup,
        MigrationExecutionResult,
        MigrationFileReport,
        MigrationFileStatus,
        MigrationReport,
        backupProjectLib,
        convertDartToQuds,
        executeProjectMigration,
        inspectProjectForMigration;
