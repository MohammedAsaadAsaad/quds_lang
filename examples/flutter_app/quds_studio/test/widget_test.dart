import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds/interpreter.dart';
import 'package:quds_studio/main.dart';
import 'package:quds_studio/presets.dart';
import 'package:quds_studio/viz_widgets.dart';

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

  testWidgets(
      'Mobile phone viewport renders 3-tab bottom NavigationBar without overflow',
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

  testWidgets(
      'Smart Enter auto-indents after colon, Tab/Outdent buttons work, and Custom Policy applies dynamically',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const QudsStudioApp(initialPresetIndex: 2, autoRunInitial: false),
    );
    await tester.pumpAndSettle();

    // 1. Smart Enter after `repeat 10:` indents 2 spaces
    final tfFinder = find.byKey(const Key('quds_code_textfield'));
    final tf = tester.widget<TextField>(tfFinder);
    final afterEnter = tf.inputFormatters!.first.formatEditUpdate(
      const TextEditingValue(
        text: 'repeat 10:',
        selection: TextSelection.collapsed(offset: 10),
      ),
      const TextEditingValue(
        text: 'repeat 10:\n',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    expect(afterEnter.text, 'repeat 10:\n  ');
    expect(afterEnter.selection.baseOffset, 13);

    // 2. VS Code-style Tab & Outdent quick-key buttons
    tf.controller!.value = const TextEditingValue(
      text: 'print "hi"',
      selection: TextSelection.collapsed(offset: 0),
    );
    await tester.tap(find.byKey(const Key('studio_btn_indent')));
    await tester.pumpAndSettle();
    expect(tf.controller!.text, '  print "hi"');

    await tester.tap(find.byKey(const Key('studio_btn_outdent')));
    await tester.pumpAndSettle();
    expect(tf.controller!.text, 'print "hi"');

    // 3. Horizontal scrolling is enabled by default and toggles cleanly with Wrap button
    expect(find.byKey(const Key('studio_editor_hscroll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_toggle_wrap')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studio_editor_hscroll')), findsNothing);
    await tester.tap(find.byKey(const Key('btn_toggle_wrap')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studio_editor_hscroll')), findsOneWidget);

    // 4. Open Custom Policy dialog and grant host:sensors dynamically
    await tester.tap(find.byKey(const Key('btn_custom_policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch_allow_sensors')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_apply_custom_policy')));
    await tester.pumpAndSettle();
    expect(find.text('مخصّص'), findsOneWidget);
  });

  testWidgets(
      'Quds Studio showcases 60fps animation, 3D Surface + Vector Field, Graph, Data/FFT, Micro-App Form, Call Tree, Time-Travel, Bytecode VM, and Reactive Notebook',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Preset 4: 60fps Physics Pendulum + Animation Controls Bar
    await tester.pumpWidget(
        const QudsStudioApp(key: ValueKey(4), initialPresetIndex: 4));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
    expect(find.byKey(const Key('quds_animation_bar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_anim_step')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('quds_animation_bar')),
        matching: find.textContaining('#1'),
      ),
      findsOneWidget,
    );

    // 2. Preset 5: 3D Surface + Vector Field
    await tester.pumpWidget(
        const QudsStudioApp(key: ValueKey(5), initialPresetIndex: 5));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_surface3d_canvas')), findsOneWidget);
    expect(find.byKey(const Key('quds_vector_field_canvas')), findsOneWidget);

    // 3. Preset 6: Interactive Graph
    await tester.pumpWidget(
        const QudsStudioApp(key: ValueKey(6), initialPresetIndex: 6));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_graph_canvas')), findsOneWidget);

    // 4. Preset 7: DataTable CSV + FFT Spectrum
    await tester.pumpWidget(
        const QudsStudioApp(key: ValueKey(7), initialPresetIndex: 7));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('متوسط المبيعات حسب المدينة'), findsOneWidget);

    // 5. Preset 8: Micro-App Form Controls
    await tester.pumpWidget(
        const QudsStudioApp(key: ValueKey(8), initialPresetIndex: 8));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_form_output_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_input_recalc')));
    await tester.pumpAndSettle();
    expect(find.textContaining('(1)'), findsOneWidget);

    // 6. Preset 9: Call Tree Profiler + Time-Travel + Bytecode VM + Notebook tab
    await tester.pumpWidget(
        const QudsStudioApp(key: ValueKey(9), initialPresetIndex: 9));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_profiler_tab')), findsOneWidget);
    expect(find.textContaining('fib(1) => 1'), findsWidgets);

    // Disable Trace and enable Bytecode VM -> verify ⚡ VM execution badge!
    await tester.tap(find.byKey(const Key('chip_profiler_timetravel')));
    await tester.tap(find.byKey(const Key('chip_bytecode_vm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_run')));
    await tester.pumpAndSettle();
    expect(find.textContaining('⚡ VM ·'), findsOneWidget);

    // Switch to Notebook tab inside Inspector
    await tester.tap(find.text('الدفتر التفاعلي'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_notebook_panel')), findsOneWidget);
  });

  testWidgets(
      'Quds Studio Multi-File Project Workspace browses nested folders, edits modules, and executes project',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const QudsStudioApp(
        key: ValueKey('workspace_test'), autoRunInitial: false));
    await tester.pumpAndSettle();

    // Open the 6th Inspector tab: Project Workspace (scroll TabBar into view first)
    final projTab = find.byKey(const Key('inspector_project_tab'));
    await tester.ensureVisible(projTab);
    await tester.pumpAndSettle();
    await tester.tap(projTab);
    await tester.pumpAndSettle();

    // Verify nested files & folders from orbital_lab template are listed
    expect(find.text('orbital_lab'), findsOneWidget);
    expect(
        find.byKey(const Key('ws_file_core/constants.quds')), findsOneWidget);
    expect(find.byKey(const Key('ws_file_math/vec.quds')), findsOneWidget);

    // Open nested file `core/constants.quds` into editor
    await tester.tap(find.byKey(const Key('ws_file_core/constants.quds')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace_active_file_bar')), findsOneWidget);
    expect(find.textContaining('orbital_lab / core/constants.quds'),
        findsOneWidget);

    // Run full multi-file project (executes `main.quds` importing physics/index -> integrator -> core/constants + math/vec!)
    await tester.tap(find.byKey(const Key('workspace_run_project_btn')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify live Plot Canvas, Summary Table, and Interactive Sliders rendered from multi-file execution!
    expect(find.byType(QudsPlotCanvas), findsOneWidget);
    expect(find.text('ملخص المحاكاة'), findsOneWidget);
    expect(find.textContaining('السرعة الابتدائية'), findsOneWidget);
  });

  testWidgets(
      'Quds Studio renders live telemetry HUD for Pendulum and progressive gradient Butterfly with timeline scrubber',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Pendulum preset (index 4): live telemetry HUD + timeline scrubber
    await tester.pumpWidget(const QudsStudioApp(
      key: ValueKey('pendulum_hud'),
      initialPresetIndex: 4,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
    expect(find.byKey(const Key('quds_telemetry_hud')), findsOneWidget);
    expect(find.byKey(const Key('anim_timeline_scrubber')), findsOneWidget);
    expect(find.textContaining('KE:'), findsOneWidget);
    expect(find.textContaining('PE:'), findsOneWidget);

    // 2. Temple Fay Butterfly preset (index 10): progressive gradient drawing + live progress HUD
    await tester.pumpWidget(const QudsStudioApp(
      key: ValueKey('butterfly_hud'),
      initialPresetIndex: 10,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
    expect(find.byKey(const Key('quds_telemetry_hud')), findsOneWidget);
    expect(find.textContaining('0.0 %'), findsOneWidget);
    expect(find.textContaining('0/320'), findsOneWidget);

    // Step forward several frames -> percentage and drawn points advance from first point!
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('btn_anim_step')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('0.0 %'), findsNothing);
    expect(find.textContaining('#4'), findsOneWidget);
  });

  test(
      'All 24 real-time motion presets (Physics, Chemistry, Mathematics, Geometry, Waves, Space) execute cleanly across multiple time frames with live telemetry',
      () async {
    final animated = studioPresets.where((p) => p.isAnimated).toList();
    expect(animated, hasLength(24));

    for (final preset in animated) {
      final session = QudsSession(allowTopLevelRebind: true);
      final frames = await session.runTimeline(
        preset.code,
        frames: 4,
        dt: 0.25,
        file: preset.fileName,
      );
      await session.dispose();

      expect(frames, hasLength(4), reason: 'Preset ${preset.id} frame count');
      for (var i = 0; i < frames.length; i++) {
        final f = frames[i];
        expect(f.succeeded, isTrue,
            reason: 'Preset ${preset.id} failed on frame $i: ${f.error}');
        final scene = f.lastGeometryScene;
        expect(scene, isNotNull,
            reason: 'Preset ${preset.id} missing geometry scene on frame $i');
        expect(scene!.animation, isNotNull,
            reason: 'Preset ${preset.id} missing animation spec on frame $i');
        expect(scene.readings, isNotEmpty,
            reason:
                'Preset ${preset.id} missing telemetry readings on frame $i');
      }
    }
  });

  testWidgets(
      'Quick-Switch category bar, Prev/Next stepper, and Examples Gallery switch motion presets seamlessly',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const QudsStudioApp(
        key: ValueKey('gallery_test'), autoRunInitial: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preset_quick_bar')), findsOneWidget);

    // Filter to live motion presets (`⚡ حركة حية (12)`)
    await tester.tap(find.byKey(const Key('filter_animatedOnly')));
    await tester.pumpAndSettle();

    // Open full categorized Examples Gallery dialog and select Solar Orbit
    await tester.tap(find.byKey(const Key('btn_preset_gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gallery_item_solar_orbit')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify Solar Orbit ran live with telemetry HUD
    expect(find.byKey(const Key('quds_geometry_canvas')), findsOneWidget);
    expect(find.byKey(const Key('quds_telemetry_hud')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('quds_telemetry_hud')),
        matching: find.textContaining('AU'),
      ),
      findsOneWidget,
    );

    // Step to next motion preset via 1-tap Next button (`btn_next_preset`) -> Spirograph Rose
    await tester.tap(find.byKey(const Key('btn_next_preset')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('البتلات'), findsWidgets);
  });

  testWidgets(
      'Mobile phone layout keeps compact header, scrollable visual stage with >=300px unobstructed canvas, standalone telemetry HUD, and settings sheet',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Preset 16: projectile_live (animation + telemetry HUD + multiple sliders)
    await tester.pumpWidget(
      const QudsStudioApp(
          key: ValueKey('mobile_scroll'), initialPresetIndex: 16),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Switch to Canvas tab on mobile bottom NavigationBar
    await tester.tap(find.text('اللوحة'));
    await tester.pumpAndSettle();

    // 1. Visual stage is vertically scrollable and canvas is guaranteed >= 300px tall
    expect(find.byKey(const Key('visual_stage_scroll')), findsOneWidget);
    final canvasSize =
        tester.getSize(find.byKey(const Key('quds_geometry_canvas')));
    expect(canvasSize.height, greaterThanOrEqualTo(300.0));

    // 2. Standalone telemetry HUD renders cleanly below canvas (never overlapping it)
    final canvasRect =
        tester.getRect(find.byKey(const Key('quds_geometry_canvas')));
    final hudRect = tester.getRect(find.byKey(const Key('quds_telemetry_hud')));
    expect(hudRect.top, greaterThanOrEqualTo(canvasRect.bottom));

    // 3. Scroll down inside visual_stage_scroll to verify sliders are smoothly reachable
    await tester.drag(
      find.byKey(const Key('visual_stage_scroll')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('slider_v0')), findsOneWidget);

    // 4. Compact mobile settings button opens BottomSheet with Policy & Engine toggles
    await tester.tap(find.byKey(const Key('btn_mobile_settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('policy_selector')), findsOneWidget);
    expect(find.byKey(const Key('btn_custom_policy')), findsOneWidget);
  });

  testWidgets(
      'Line Quality panel controls sharpness, smoothness, glow, and anti-aliasing live, and Chemistry/Math categories run smoothly',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const QudsStudioApp(
          key: ValueKey('line_quality_test'), initialPresetIndex: 12),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 1. Open inline Line Quality panel from Visual Stage header
    await tester.tap(find.byKey(const Key('btn_line_quality')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quds_line_quality_panel')), findsOneWidget);

    // 2. Switch to Razor Crisp preset -> verify glow drops to 0.0 and strokeScale updates
    await tester.tap(find.byKey(const Key('line_preset_crisp')));
    await tester.pumpAndSettle();
    var geoCanvas =
        tester.widget<QudsGeometryCanvas>(find.byType(QudsGeometryCanvas));
    expect(geoCanvas.lineStyle, QudsLineStyleSettings.crisp);

    // 3. Toggle Anti-Aliasing -> AA OFF
    await tester.tap(find.byKey(const Key('toggle_line_aa')));
    await tester.pumpAndSettle();
    geoCanvas =
        tester.widget<QudsGeometryCanvas>(find.byType(QudsGeometryCanvas));
    expect(geoCanvas.lineStyle.antiAlias, isFalse);

    // 4. Switch to Soft Glow preset -> full smoothness + glow
    await tester.tap(find.byKey(const Key('line_preset_softGlow')));
    await tester.pumpAndSettle();
    geoCanvas =
        tester.widget<QudsGeometryCanvas>(find.byType(QudsGeometryCanvas));
    expect(geoCanvas.lineStyle, QudsLineStyleSettings.softGlow);

    // 5. Filter by Chemistry and run Titration pH curve live via Gallery
    await tester.tap(find.byKey(const Key('filter_chemistry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_preset_gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gallery_item_chem_titration_ph')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      find.descendant(
        of: find.byKey(const Key('quds_telemetry_hud')),
        matching: find.textContaining('pH اللحظي'),
      ),
      findsOneWidget,
    );

    // 6. Filter by Mathematics and run Riemann Integral live via Gallery
    await tester.tap(find.byKey(const Key('filter_mathematics')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_preset_gallery')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('gallery_item_math_riemann_integral')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      find.descendant(
        of: find.byKey(const Key('quds_telemetry_hud')),
        matching: find.textContaining('مجموع ريمان'),
      ),
      findsOneWidget,
    );
  });
}
