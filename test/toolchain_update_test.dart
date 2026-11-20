import 'dart:io';
import 'package:quds_lang/src/toolchain_update.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory remote;
  late Directory checkout;
  late Directory author;
  Future<String> git(Directory dir, List<String> args) async {
    final run = await Process.run('git', ['-C', dir.path, ...args]);
    if (run.exitCode != 0) throw StateError('${run.stdout}${run.stderr}');
    return '${run.stdout}'.trim();
  }

  Future<void> commit(Directory dir, String content) async {
    File('${dir.path}/value').writeAsStringSync(content);
    await git(dir, ['add', 'value']);
    await git(dir, [
      '-c',
      'user.name=Test',
      '-c',
      'user.email=test@example.invalid',
      'commit',
      '-m',
      content
    ]);
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('quds-update-');
    remote = Directory('${root.path}/origin')..createSync();
    author = Directory('${root.path}/author')..createSync();
    checkout = Directory('${root.path}/checkout');
    await git(remote, ['init', '--bare', '--initial-branch=main']);
    await git(author, ['init', '--initial-branch=main']);
    await commit(author, 'first');
    await git(author, ['remote', 'add', 'origin', remote.path]);
    await git(author, ['push', 'origin', 'main']);
    await git(root, ['clone', remote.path, checkout.path]);
  });
  tearDown(() => root.deleteSync(recursive: true));
  test('clean checkout fast-forwards and a repeated update is idempotent',
      () async {
    await commit(author, 'second');
    await git(author, ['push', 'origin', 'main']);
    expect(await updateCompilerCheckout(checkout, report: (_) {}), true);
    expect(File('${checkout.path}/value').readAsStringSync(), 'second');
    expect(await updateCompilerCheckout(checkout, report: (_) {}), true);
  });
  test('tracked changes are preserved and block update', () async {
    File('${checkout.path}/value').writeAsStringSync('local');
    expect(await updateCompilerCheckout(checkout, report: (_) {}), false);
    expect(File('${checkout.path}/value').readAsStringSync(), 'local');
  });
  test('divergence preserves both local commit and files', () async {
    await commit(checkout, 'local');
    final head = await git(checkout, ['rev-parse', 'HEAD']);
    await commit(author, 'remote');
    await git(author, ['push', 'origin', 'main']);
    expect(await updateCompilerCheckout(checkout, report: (_) {}), false);
    expect(await git(checkout, ['rev-parse', 'HEAD']), head);
    expect(File('${checkout.path}/value').readAsStringSync(), 'local');
  });
  test('detached checkout may safely fast-forward', () async {
    await git(checkout, ['checkout', '--detach']);
    await commit(author, 'second');
    await git(author, ['push', 'origin', 'main']);
    expect(await updateCompilerCheckout(checkout, report: (_) {}), true);
    expect(File('${checkout.path}/value').readAsStringSync(), 'second');
  });
  test('missing remote fails without installing or altering HEAD', () async {
    final head = await git(checkout, ['rev-parse', 'HEAD']);
    await git(
        checkout, ['remote', 'set-url', 'origin', '${root.path}/missing']);
    expect(await updateCompilerCheckout(checkout, report: (_) {}), false);
    expect(await git(checkout, ['rev-parse', 'HEAD']), head);
  });
  test('archive installation gives an explicit no-update route', () async {
    final archive = Directory('${root.path}/archive')..createSync();
    final messages = <String>[];
    expect(await updateCompilerCheckout(archive, report: messages.add), false);
    expect(messages.join(), contains('--no-update'));
  });
}
