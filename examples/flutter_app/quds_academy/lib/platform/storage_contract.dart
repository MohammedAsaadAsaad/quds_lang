import 'dart:typed_data';

/// Platform byte transport only. All SQL and progress logic lives in Quds.
abstract interface class AcademyStorage {
  bool get persistent;
  Future<Uint8List?> load();
  Future<void> save(Uint8List image);
}
