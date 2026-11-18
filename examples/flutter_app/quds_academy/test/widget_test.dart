import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_academy/platform/storage_contract.dart';
import 'package:quds_academy/quds_gen/main.dart';

class TestStorage implements AcademyStorage {
  Uint8List? bytes;
  bool fail = false;
  @override
  bool persistent = true;
  @override
  Future<Uint8List?> load() async {
    if (fail) throw StateError('Unavailable');
    return bytes == null ? null : Uint8List.fromList(bytes!);
  }

  @override
  Future<void> save(Uint8List image) async {
    if (fail) throw StateError('Unavailable');
    bytes = Uint8List.fromList(image);
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['ACADEMY_SCREENSHOTS'];
  if (directory == null) return;
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  await tester.runAsync(() async {
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['Cairo', 'JetBrainsMono']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });

  testWidgets(
      'desktop bilingual learning, execution, saved progress and reference',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = TestStorage();
    final boundary = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: Academy(storage: storage)));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ صغيرًا.\nوابنِ بلا حدود.'), findsOneWidget);
    await capture(tester, boundary, 'desktop-ar');
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Small syntax.\nBig possibilities.'), findsOneWidget);
    await capture(tester, boundary, 'desktop-en');
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    final run = find.text('Run lesson demo');
    await tester.ensureVisible(run);
    await tester.tap(run);
    await tester.pumpAndSettle();
    expect(find.text('Hello Quds'), findsOneWidget);
    final correct = find.text('A colon :');
    await tester.ensureVisible(correct);
    await tester.tap(correct);
    await tester.pumpAndSettle();
    final finish = find.text('Complete lesson · +25 points');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Lesson completed'), findsOneWidget);
    expect(storage.bytes, isNotEmpty);
    await capture(tester, boundary, 'lesson-en');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: Academy(storage: storage)));
    await tester.pumpAndSettle();
    expect(find.text('Small syntax.\nBig possibilities.'), findsOneWidget);
    await tester.tap(find.text('My progress'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 12 lessons completed'), findsOneWidget);
    await tester.tap(find.text('Reference'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'augment');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'augment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Adds declarations'), findsOneWidget);
    await capture(tester, boundary, 'reference-en');
    await tester.tap(find.byTooltip('Toggle appearance'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone RTL navigation and large text stay within bounds',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: Academy(storage: TestStorage())));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await capture(tester, boundary, 'phone-ar');
    for (final title in ['تعلّم', 'المرجع', 'تقدّمي', 'الرئيسية']) {
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
    }
  });

  testWidgets('storage errors offer retry without replacing saved data',
      (tester) async {
    final storage = TestStorage()..fail = true;
    await tester.pumpWidget(Academy(storage: storage));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر فتح تقدّمك'), findsOneWidget);
    expect(storage.bytes, isNull);
    storage.fail = false;
    await tester.tap(find.text('حاول مجددًا'));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ صغيرًا.\nوابنِ بلا حدود.'), findsOneWidget);
  });
}
