import 'dart:typed_data';

import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

Uint8List _gradientBmp(int w, int h) {
  final rows = List.generate(
    h,
    (y) => List.generate(
      w,
      (x) => [(20 + x * 25).clamp(0, 255), (180 - y * 20).clamp(0, 255), 220],
    ),
  );
  return encodeQudsBmp24(rows);
}

void main() {
  group('QudsWorkspace assets & .qproj v2 serialization', () {
    test(
        'stores text and binary assets, reports tree metadata, and round-trips .qproj JSON',
        () {
      final bmp = _gradientBmp(4, 3);
      final ws = QudsWorkspace(
        name: 'asset_demo',
        files: {
          'main.quds': 'print "ok"',
          'assets/config.json': '{"theme": "emerald", "tax": 0.16}',
          'assets/items.csv': 'sku,name,price\nA1,Coffee,12.5\nA2,Tea,7.0\n',
        },
        binaryAssets: {
          'assets/logo.bmp': bmp,
        },
      );

      expect(ws.assetCount, 3);
      expect(ws.isBinaryFile('assets/logo.bmp'), isTrue);
      expect(ws.isBinaryFile('assets/config.json'), isFalse);
      expect(ws.hasAnyFile('assets/logo.bmp'), isTrue);
      expect(ws.readAssetBytes('assets/logo.bmp'), equals(bmp));
      expect(
        QudsWorkspace.mimeTypeForPath('assets/logo.bmp'),
        equals('image/bmp'),
      );
      expect(
        ws.listAllEntries(inFolder: 'assets'),
        equals(['assets/config.json', 'assets/items.csv', 'assets/logo.bmp']),
      );

      // Dependency analysis must cleanly ignore non-.quds assets
      final deps = ws.analyzeDependencies();
      expect(deps.hasCycles, isFalse);
      expect(deps.hasUnresolvedImports, isFalse);

      // Tree nodes include binary flag & byte size
      final root = ws.buildTree();
      final assetsFolder = root.children.firstWhere((n) => n.path == 'assets');
      final bmpNode =
          assetsFolder.children.firstWhere((n) => n.path == 'assets/logo.bmp');
      expect(bmpNode.isBinary, isTrue);
      expect(bmpNode.byteSize, equals(bmp.length));

      // Round-trip via .qproj JSON string
      final serialized = ws.toJsonString();
      final restored = QudsWorkspace.fromJsonString(serialized);
      expect(restored.name, 'asset_demo');
      expect(restored.readFile('assets/config.json'),
          equals('{"theme": "emerald", "tax": 0.16}'));
      expect(restored.readAssetBytes('assets/logo.bmp'), equals(bmp));
      expect(restored.assetCount, 3);

      // Rename & delete binary asset
      restored.renameFile('assets/logo.bmp', 'assets/brand.bmp');
      expect(restored.hasAnyFile('assets/logo.bmp'), isFalse);
      expect(restored.readAssetBytes('assets/brand.bmp'), equals(bmp));
      expect(restored.deleteFile('assets/brand.bmp'), isTrue);
      expect(restored.hasAnyFile('assets/brand.bmp'), isFalse);
    });
  });

  group('quds:assets module in QudsSession (VM & AST)', () {
    QudsWorkspace buildSampleWorkspace() {
      final bmp = _gradientBmp(8, 6);
      return QudsWorkspace(
        name: 'shop_test',
        files: {
          'assets/store.json': '{"name": "Quds Market", "vat": 0.15}',
          'assets/sales.csv': 'item,qty,price\nDates,3,18.0\nOliveOil,2,45.0\n',
          'assets/readme.txt': 'Welcome to Quds Assets!',
          'lib/pricing.quds': '''
totalWithVat(subtotal: double, vat: double) -> double:
  return subtotal * (1.0 + vat)
''',
          'main.quds': '''
use quds:assets as assets
use lib.pricing show totalWithVat

cfg = assets.readJson("assets/store.json")
rows = assets.readCsv("assets/sales.csv")
greeting = assets.readText("assets/readme.txt")
meta = assets.info("assets/banner.bmp")
b64 = assets.readBase64("assets/banner.bmp")
rawBytes = assets.readBytes("assets/banner.bmp")
allAssets = assets.list("assets")

var subtotal = 0.0
for row in rows:
  subtotal = subtotal + (row["qty"] as num).toDouble() * (row["price"] as num).toDouble()

grand = totalWithVat(subtotal, (cfg["vat"] as num).toDouble())

report = map:
  "store": cfg["name"]
  "grandTotal": grand
assets.writeJson("assets/report.json", report)
assets.renderImage("assets/banner.bmp", title: "Store Banner", caption: greeting)
assets.renderPixelGrid(
  [
    ["#10B981", "#38BDF8"],
    ["#F59E0B", "#EC4899"]
  ],
  title: "Palette Swatch",
  scale: 4,
)

print "{cfg['name']}|{grand.toStringAsFixed(2)}|{meta['mimeType']}|{rawBytes.length}|{allAssets.length}|{b64.length > 10}"
''',
        },
        binaryAssets: {
          'assets/banner.bmp': bmp,
        },
      );
    }

    for (final preferBytecode in [true, false]) {
      test(
        'reads JSON/CSV/Text/Bytes, writes JSON, and renders images (${preferBytecode ? "Register VM" : "AST"})',
        () async {
          final ws = buildSampleWorkspace();
          final session = QudsSession(
            policy: QudsExecutionPolicy.scientific(),
          )..attachWorkspace(ws);

          final res = await session.runProject(preferBytecode: preferBytecode);
          expect(res.succeeded, isTrue, reason: '${res.error}');
          expect(res.printedLines, hasLength(1));
          // Subtotal = 3*18 + 2*45 = 54 + 90 = 144; 144 * 1.15 = 165.60
          expect(res.printedLines.first,
              startsWith('Quds Market|165.60|image/bmp|'));
          expect(res.printedLines.first, endsWith('|4|true'));

          // Wrote new JSON asset back into workspace
          expect(ws.hasAnyFile('assets/report.json'), isTrue);
          expect(ws.readFile('assets/report.json'), contains('165.6'));

          // Emitted two QudsImageOutput cards (banner.bmp + procedural pixel grid)
          final images = res.outputs.whereType<QudsImageOutput>().toList();
          expect(images, hasLength(2));
          expect(images[0].title, 'Store Banner');
          expect(images[0].width, 8);
          expect(images[0].height, 6);
          expect(images[0].mimeType, 'image/bmp');
          expect(images[1].title, 'Palette Swatch');
          expect(images[1].width, 8); // 2 * scale(4)
          expect(images[1].height, 8);
        },
      );
    }

    test(
        'policy blocks quds:assets in strictSandbox and blocks writes when allowMutation is false',
        () async {
      final ws = QudsWorkspace(
        files: {
          'assets/a.txt': 'hello',
          'main.quds': '''
use quds:assets as assets
print assets.readText("assets/a.txt")
''',
        },
      );

      final strict = QudsSession(
        policy: QudsExecutionPolicy.strictSandbox(),
      )..attachWorkspace(ws);
      final deniedImport = await strict.runProject();
      expect(deniedImport.succeeded, isFalse);

      final readOnlyWs = QudsWorkspace(
        files: {
          'assets/a.txt': 'hello',
          'main.quds': '''
use quds:assets as assets
assets.writeText("assets/out.txt", "blocked")
''',
        },
      );
      final readOnlySession = QudsSession(
        policy: QudsExecutionPolicy.scientific().copyWith(allowMutation: false),
      )..attachWorkspace(readOnlyWs);
      final deniedWrite = await readOnlySession.runProject();
      expect(deniedWrite.succeeded, isFalse);
      expect(readOnlyWs.hasAnyFile('assets/out.txt'), isFalse);
    });

    test('writeBytes stores binary asset and can be read back', () async {
      final ws = QudsWorkspace(
        files: {
          'main.quds': '''
use quds:assets as assets
assets.writeBytes("assets/raw.bin", [65, 66, 67, 68])
info = assets.info("assets/raw.bin")
bytes = assets.readBytes("assets/raw.bin")
print "{info['isBinary']}|{bytes.length}|{bytes[0]}"
''',
        },
      );
      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(),
      )..attachWorkspace(ws);
      final res = await session.runProject(preferBytecode: true);
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, equals(['true|4|65']));
      expect(
        ws.readAssetBytes('assets/raw.bin'),
        equals(Uint8List.fromList([65, 66, 67, 68])),
      );
    });
  });
}
