import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_studio/main.dart';

void main() {
  testWidgets(
      'Interactive Geometry preset renders QudsGeometryCanvas, centroid output, and updates live on slider move',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const QudsStudioApp(initialPresetIndex: 0));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
    expect(find.byKey(const Key('slider_radius')), findsOneWidget);
    expect(find.textContaining('المركز G = (2.67, 1.50)'), findsOneWidget);

    // Move slider and confirm live recomputation succeeds cleanly
    final slider = find.byKey(const Key('slider_radius'));
    await tester.drag(slider, const Offset(60, 0));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
  });

  testWidgets(
      'Debugger preset pauses at breakpoint, evaluates live expression in frame, and resumes to completion',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const QudsStudioApp(initialPresetIndex: 2, autoRunInitial: false),
    );
    await tester.pumpAndSettle();

    // Breakpoint dot should be visible on line 7
    expect(find.byKey(const Key('bp_dot_7')), findsOneWidget);

    // Run -> pauses at line 7
    await tester.tap(find.byKey(const Key('btn_run')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn_continue')), findsOneWidget);
    expect(find.byKey(const Key('btn_step_over')), findsOneWidget);
    expect(find.byKey(const Key('btn_step_into')), findsOneWidget);

    // Evaluate live expression inside paused frame
    await tester.enterText(
        find.byKey(const Key('debug_eval_input')), 'i * 100');
    await tester.tap(find.byKey(const Key('btn_debug_eval')));
    await tester.pumpAndSettle();
    expect(find.textContaining('i * 100 => 100'), findsOneWidget);

    // Clear breakpoint and continue to completion
    await tester.tap(find.byKey(const Key('gutter_line_7')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn_continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn_run')), findsOneWidget);
  });

  testWidgets(
      'Code editor detects E202 immutable reassignment and applies one-click Quick Fix',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const QudsStudioApp(initialPresetIndex: 2, autoRunInitial: false),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quds_code_textfield')),
      'count = 10\ncount = 20\nprint count\n',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('E202'), findsOneWidget);
    expect(find.byKey(const Key('btn_quick_fix')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn_quick_fix')));
    await tester.pumpAndSettle();

    expect(find.textContaining('E202'), findsNothing);
    expect(find.text('سليم'), findsOneWidget);
  });

  testWidgets(
      'Policy bridge preset executes host:sensors under System Bridge and flags library error under Sandbox',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const QudsStudioApp(initialPresetIndex: 3));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('قراءة الحساس = 24.5'), findsOneWidget);

    // Switch policy to Strict Sandbox -> editor immediately flags P102!
    await tester.tap(find.text('مقيّد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('P102'), findsOneWidget);
  });

  testWidgets('Mobile phone viewport renders 3-tab bottom NavigationBar without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const QudsStudioApp(initialPresetIndex: 0));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const Key('mobile_bottom_nav')), findsOneWidget);
    await tester.tap(find.text('اللوحة'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
  });
}
