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
        RepaintBoundary(
          key: boundary,
          child: Academy(storage: storage),
        ),
      );
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
        RepaintBoundary(
          key: boundary,
          child: Academy(storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Small syntax.\nBig possibilities.'), findsOneWidget);
      await tester.tap(find.text('My progress'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 12 lessons completed'), findsOneWidget);
      await tester.tap(find.text('Reference'));
      await tester.pumpAndSettle();
      expect(find.text('Conversions & augmentation'), findsOneWidget);
      await tester.ensureVisible(find.text('Conversions & augmentation'));
      await tester.tap(find.text('Conversions & augmentation'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'augment'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'while'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'augment'));
      await tester.pumpAndSettle();
      final code = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      expect(code.textSpan, isNotNull);
      expect(code.textSpan!.children!.length, greaterThan(1));
      await tester.ensureVisible(find.text('All categories'));
      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'augment');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'augment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Adds declarations'), findsOneWidget);
      await capture(tester, boundary, 'reference-en');
      await tester.tap(find.byTooltip('Toggle appearance'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone RTL navigation and large text stay within bounds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: Academy(storage: TestStorage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await capture(tester, boundary, 'phone-ar');
    for (final title in ['تعلّم', 'المرجع', 'تقدّمي', 'المختبر', 'الرئيسية']) {
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
      if (title == 'المرجع') {
        final category = find.text('التحويلات والإضافة');
        await tester.ensureVisible(category);
        await tester.tap(category);
        await tester.pumpAndSettle();
        final word = find.widgetWithText(ChoiceChip, 'to?');
        await tester.ensureVisible(word);
        await tester.tap(word);
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'embedded playground executes custom Quds code, math SDK, and geometry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(Academy(storage: TestStorage()));
      await tester.pumpAndSettle();

      // Open Playground from sidebar
      await tester.tap(find.text('المختبر').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('academy_playground_editor')),
        findsOneWidget,
      );

      // Academy Playground stays clean without policy/restriction chips
      expect(find.text('وضع مقيّد'), findsNothing);
      expect(find.text('وضع علمي'), findsNothing);

      // Horizontal scrolling is enabled by default and toggles cleanly with Wrap button
      expect(find.byKey(const Key('academy_editor_hscroll')), findsOneWidget);
      await tester.tap(find.byKey(const Key('academy_btn_toggle_wrap')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('academy_editor_hscroll')), findsNothing);
      await tester.tap(find.byKey(const Key('academy_btn_toggle_wrap')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('academy_editor_hscroll')), findsOneWidget);

      // Test VS Code-style Tab / Outdent buttons and smart Enter after `:`
      final editorFinder = find.byKey(const Key('academy_playground_editor'));
      await tester.enterText(editorFinder, 'repeat 10:');
      await tester.pumpAndSettle();
      final tf = tester.widget<TextField>(editorFinder);
      // Simulate Android soft-keyboard inserting newline via TextInputFormatter
      final formatted = tf.inputFormatters!.first.formatEditUpdate(
        const TextEditingValue(
          text: 'repeat 10:',
          selection: TextSelection.collapsed(offset: 10),
        ),
        const TextEditingValue(
          text: 'repeat 10:\n',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      expect(formatted.text, 'repeat 10:\n  ');
      expect(formatted.selection.baseOffset, 13);

      // Tap Tab & Outdent quick-key buttons
      tf.controller!.value = const TextEditingValue(
        text: 'x = 1',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.tap(find.byKey(const Key('academy_btn_indent')));
      await tester.pumpAndSettle();
      expect(tf.controller!.text, '  x = 1');
      await tester.tap(find.byKey(const Key('academy_btn_outdent')));
      await tester.pumpAndSettle();
      expect(tf.controller!.text, 'x = 1');

      // Enter custom Quds code using quds:math and execute via embedded interpreter
      await tester.enterText(
        editorFinder,
        'use quds:math\n'
        'vals = [10.0, 20.0, 30.0]\n'
        'print "avg={mean(vals)}"\n',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('academy_playground_run')));
      await tester.pumpAndSettle();
      expect(find.textContaining('avg=20.0'), findsOneWidget);

      // Switch to the Interactive Geometry starter snippet and run it
      await tester.tap(find.text('هندسة تفاعلية'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('academy_playground_run')));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lesson code opens in Playground and executes via interpreter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(Academy(storage: TestStorage()));
    await tester.pumpAndSettle();

    // Switch to English and open lesson 1
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();

    // Tap "Try in Playground" button next to Run lesson demo
    final tryBtn = find.text('Try in Playground');
    await tester.ensureVisible(tryBtn);
    await tester.tap(tryBtn);
    await tester.pumpAndSettle();

    // Verify Playground loaded the lesson code and executes main() live
    final editor = tester.widget<TextField>(
      find.byKey(const Key('academy_playground_editor')),
    );
    expect(editor.controller!.text, contains('print "Hello {name}"'));

    await tester.tap(find.byKey(const Key('academy_playground_run')));
    await tester.pumpAndSettle();
    final consoleOutput = tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    );
    expect(
      consoleOutput.any((w) => (w.data ?? '').contains('Hello Quds')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage errors offer retry without replacing saved data', (
    tester,
  ) async {
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
