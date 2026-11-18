import 'storage_contract.dart';
import 'storage_browser.dart' if (dart.library.io) 'storage_native.dart'
    as platform;
export 'storage_contract.dart';

Future<AcademyStorage> openAcademyStorage() => platform.openStorage();
