import 'dart:io';

/// Updates only a clean compiler checkout, preserving local work and ancestry.
/// A detached checkout may fast-forward; divergence is never merged or reset.
Future<bool> updateCompilerCheckout(Directory root,
    {void Function(String)? report}) async {
  final output = report ?? stdout.writeln;
  Future<ProcessResult> git(List<String> args) =>
      Process.run('git', ['-C', root.path, ...args],
          environment: {'GIT_TERMINAL_PROMPT': '0'});
  try {
    final top = await git(['rev-parse', '--show-toplevel']);
    if (top.exitCode != 0 ||
        Directory('${top.stdout}'.trim()).resolveSymbolicLinksSync() !=
            root.resolveSymbolicLinksSync()) {
      throw StateError('The compiler is not a standalone Git checkout. '
          'Use --no-update to install these files, or install from the GitHub checkout.');
    }
    final status = await git(['status', '--porcelain', '--untracked-files=no']);
    if (status.exitCode != 0 || '${status.stdout}'.trim().isNotEmpty) {
      throw StateError('The compiler checkout has tracked local changes. '
          'Commit or stash them first, or use --no-update to install the current files.');
    }
    output('Checking origin/main for Quds updates...');
    final fetched = await git(['fetch', 'origin', 'main']);
    if (fetched.exitCode != 0) {
      throw StateError('Update fetch failed: ${fetched.stderr}');
    }
    final merged = await git(['merge', '--ff-only', 'FETCH_HEAD']);
    if (merged.exitCode != 0) {
      throw StateError(
          'The update could not fast-forward; local work was preserved. ${merged.stderr}');
    }
    output('${merged.stdout}'.trim());
    return true;
  } on Object catch (error) {
    output('Quds update failed: $error');
    return false;
  }
}
