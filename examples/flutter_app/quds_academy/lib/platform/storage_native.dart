import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'storage_contract.dart';

Future<AcademyStorage> openStorage() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return _FileStorage(File('${directory.path}/quds_academy.sqlite'));
}

final class _FileStorage implements AcademyStorage {
  _FileStorage(this.file);
  final File file;
  @override
  bool get persistent => true;
  @override
  Future<Uint8List?> load() async =>
      await file.exists() ? file.readAsBytes() : null;
  @override
  Future<void> save(Uint8List image) async {
    final staging = File('${file.path}.next');
    await staging.writeAsBytes(image, flush: true);
    await staging.rename(file.path);
  }
}
