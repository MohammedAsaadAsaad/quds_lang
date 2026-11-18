import 'dart:typed_data';
import 'package:sqlite_plus/sqlite_plus.dart';
import 'storage_contract.dart';

Future<AcademyStorage> openStorage() async {
  final opened = await openBrowserStorage(name: 'quds_academy.sqlite');
  return _BrowserStorage(opened);
}

final class _BrowserStorage implements AcademyStorage {
  _BrowserStorage(this.opened);
  final OpenedStorage opened;
  @override
  bool get persistent =>
      opened.capabilities.placement == StoragePlacement.browser;
  @override
  Future<Uint8List?> load() async {
    final length = await opened.storage.length();
    if (length == 0) return null;
    final bytes = Uint8List(length);
    if (await opened.storage.read(0, bytes) != length) {
      throw StateError('Incomplete stored database image');
    }
    return bytes;
  }

  @override
  Future<void> save(Uint8List image) async {
    await opened.storage.truncate(image.length);
    await opened.storage.write(0, image);
    await opened.storage.sync();
  }
}
