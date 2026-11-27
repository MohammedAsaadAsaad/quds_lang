import 'dart:io';

import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';
import 'package:quds/quds.dart' show formatQuds;
import 'package:test/test.dart';

void main() {
  group('Phase 6 — Embedded Pure-Dart Code Editor Engine', () {
    test(
        'zero dart:io imports in package:quds/editor_engine.dart transitive graph',
        () {
      final visited = <String>{};
      final queue = <String>['lib/editor_engine.dart'];
      final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
          multiLine: true);

      while (queue.isNotEmpty) {
        final path = queue.removeLast();
        if (!visited.add(path)) continue;
        final content = File(path).readAsStringSync();
        for (final m in importRe.allMatches(content)) {
          final uri = m.group(1)!;
          expect(uri, isNot('dart:io'),
              reason:
                  '$path must not import dart:io for Web/Flutter portability');
          if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
          final resolved = File(path).parent.uri.resolve(uri).toFilePath();
          final rel = resolved.replaceFirst('${Directory.current.path}/', '');
          queue.add(rel);
        }
      }
      expect(visited.length, greaterThanOrEqualTo(5));
    });

    test(
        'syntax & semantic highlighting covers all Quds token categories and recovers from unclosed strings',
        () {
      final engine = QudsEditorEngine();
      const code = '''
:: geometry
/// Computes distance
# line comment
@Export
use quds:math as math
const timeout = 500ms
var total: double = math.sqrt(9.0)
msg = "total={total}"
print msg
''';
      final spans = engine.highlight(code);
      final categories = {for (final s in spans) s.category};

      expect(categories, contains(QudsTokenCategory.sectionHeader));
      expect(categories, contains(QudsTokenCategory.docComment));
      expect(categories, contains(QudsTokenCategory.comment));
      expect(categories, contains(QudsTokenCategory.annotation));
      expect(categories, contains(QudsTokenCategory.declarationKeyword));
      expect(categories, contains(QudsTokenCategory.duration));
      expect(categories, contains(QudsTokenCategory.typeName));
      expect(categories, contains(QudsTokenCategory.methodName));
      expect(categories, contains(QudsTokenCategory.number));
      expect(categories, contains(QudsTokenCategory.string));
      expect(categories, contains(QudsTokenCategory.interpolation));
      expect(categories, contains(QudsTokenCategory.builtin));

      // Verify palette resolves all token categories
      final dark = QudsEditorThemePalette.dark();
      final light = QudsEditorThemePalette.light();
      for (final s in spans) {
        expect(dark.colorFor(s.category), isNonZero);
        expect(light.colorFor(s.category), isNonZero);
      }

      // Graceful recovery on incomplete / unterminated string
      final broken = engine.highlight('x = "unterminated\ny = 42');
      expect(broken.any((s) => s.category == QudsTokenCategory.error), isTrue);
      expect(
          broken.any(
              (s) => s.text == '42' && s.category == QudsTokenCategory.number),
          isTrue);
    });

    test('formatting reuses official formatQuds identically', () {
      final engine = QudsEditorEngine();
      const messy = 'x=1+2\nif x>0:\n    print x\n';
      expect(engine.format(messy), formatQuds(messy));
    });

    test(
        'live analysis detects syntax errors, policy violations, unknown SDK sections, and provides working quick fixes',
        () {
      // 1. Policy violation detected before running
      final strictEngine = QudsEditorEngine(
        policy: QudsExecutionPolicy.strictSandbox(allowMutation: false),
      );
      final policyAnalysis = strictEngine.analyze('''
use quds:async
var x = 10
''');
      expect(policyAnalysis.hasErrors, isTrue);
      expect(policyAnalysis.diagnostics.map((d) => d.code),
          containsAll(['P102', 'P105']));

      // 2. Unknown SDK section detected with helpful hint
      final sciEngine = QudsEditorEngine(
        policy: QudsExecutionPolicy.scientific(),
      );
      final badSec = sciEngine.analyze('use quds:math::nonexistent_section\n');
      expect(badSec.hasErrors, isTrue);
      expect(badSec.diagnostics.first.code, 'E900');
      expect(badSec.diagnostics.first.help, contains('Available sections'));

      // 3. Immutable reassignment detected with executable Quick Fix
      const brokenReassign = 'score = 10\nscore = 20\n';
      final reassignAnalysis = sciEngine.analyze(brokenReassign);
      expect(reassignAnalysis.hasErrors, isTrue);
      final e202 =
          reassignAnalysis.diagnostics.firstWhere((d) => d.code == 'E202');
      expect(e202.quickFixes, isNotEmpty);

      final fixed =
          sciEngine.applyEdits(brokenReassign, e202.quickFixes.first.edits);
      expect(fixed, 'var score = 10\nscore = 20\n');
      expect(sciEngine.analyze(fixed).hasErrors, isFalse);

      // 4. Document outline & folding ranges
      final valid = sciEngine.analyze('''
class Box:
  width: double required
  area() -> double:
    return width * width

compute(n: int) -> int:
  return n * 2
''');
      expect(valid.hasErrors, isFalse);
      expect(valid.symbols.map((s) => s.name), ['Box', 'compute']);
      expect(
          valid.symbols.first.children.map((c) => c.name), ['width', 'area']);
      expect(valid.foldRanges, isNotEmpty);
    });

    test(
        'context-aware autocomplete covers imports, ::sections, \$. loop context, viz/scene, host modules, and live workspace',
        () async {
      final sensorMod = QudsHostModule.builder(
        'host:sensors',
        description: 'Lab temperature sensors',
      )
          .function(
            'readCelsius',
            (p, n, c) => 24.5,
            signature: 'readCelsius(channel: int) -> double',
            documentation: 'Reads current temperature in Celsius.',
          )
          .build();

      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(
          allowedLibraries: {'quds:math', 'quds:viz', 'host:sensors'},
        ),
        hostModules: [sensorMod],
      );
      await session.run('sampleRate = 1000.0');

      final engine = QudsEditorEngine(session: session);

      // 1. Import URI completion filtered by policy (quds:async hidden!)
      final impItems = engine.completeAt('use ', 4);
      final impLabels = impItems.map((i) => i.label).toSet();
      expect(impLabels, containsAll(['quds:math', 'quds:viz', 'host:sensors']));
      expect(impLabels, isNot(contains('quds:async')));

      // 2. Section completion after `quds:math::`
      const secSrc = 'use quds:math::geo';
      final secItems = engine.completeAt(secSrc, secSrc.length);
      expect(secItems.map((i) => i.label), contains('geometry'));

      // 3. Loop context `$.`
      const dollarSrc = 'for x in [1, 2]:\n  print \$.i';
      final dollarItems = engine.completeAt(dollarSrc, dollarSrc.length);
      expect(
          dollarItems.map((i) => i.label), containsAll(['index', 'isFirst']));

      // 4. `viz.` and `scene.` completions
      const vizSrc = 'use quds:viz as viz\nscene = viz.scene()\nscene.p';
      final sceneItems = engine.completeAt(vizSrc, vizSrc.length);
      expect(sceneItems.map((i) => i.label), containsAll(['point', 'polygon']));

      const vizDirect = 'use quds:viz as viz\nviz.sl';
      final vizItems = engine.completeAt(vizDirect, vizDirect.length);
      expect(vizItems.map((i) => i.label), contains('slider'));

      // 5. Custom host module prefix completion
      const hostSrc = 'use host:sensors as s\ns.read';
      final hostItems = engine.completeAt(hostSrc, hostSrc.length);
      expect(hostItems.map((i) => i.label), contains('readCelsius'));

      // 6. Live workspace variable completion + imported math symbol
      const genSrc = 'use quds:math::geometry\nx = sam';
      final genItems = engine.completeAt(genSrc, genSrc.length);
      expect(genItems.map((i) => i.label), contains('sampleRate'));

      const mathSrc = 'use quds:math::geometry\nc = poly';
      final mathItems = engine.completeAt(mathSrc, mathSrc.length);
      expect(mathItems.map((i) => i.label), contains('polygonCentroid'));

      await session.dispose();
    });

    test(
        'hover docs, signature help, and smart indentation/comment editing work accurately',
        () async {
      final session = QudsSession(policy: QudsExecutionPolicy.scientific());
      await session.run('gravity = 9.81');
      final engine = QudsEditorEngine(session: session);

      // Hover on live workspace variable
      const hoverSrc = 'use quds:math::geometry\ny = gravity * 2';
      final gravOffset = hoverSrc.indexOf('gravity') + 2;
      final gravHover = engine.hoverAt(hoverSrc, gravOffset);
      expect(gravHover, isNotNull);
      expect(gravHover!.documentation, contains('9.81'));

      // Hover on keyword
      final kwHover = engine.hoverAt('guard x > 0 else:', 2);
      expect(kwHover, isNotNull);
      expect(kwHover!.documentation, contains('guard'));

      // Signature help inside call
      const sigSrc = 'use quds:viz as viz\np = viz.point("A", 1.0, ';
      final sig = engine.signatureHelpAt(sigSrc, sigSrc.length);
      expect(sig, isNotNull);
      expect(sig!.functionName, 'point');
      expect(sig.activeParameter, 2);

      // Smart Enter after `:` indents by 2 spaces (including repeat + trailing comment)
      final nl = engine.handleNewline('repeat 10:', 10);
      expect(nl.text, 'repeat 10:\n  ');
      expect(nl.selectionStart, 13);

      final nlComment = engine.handleNewline('repeat 10: # loop', 17);
      expect(nlComment.text, 'repeat 10: # loop\n  ');

      // Smart Enter inside an indented block keeps the same indent
      const inBlock = 'repeat 10:\n  print "hi"';
      final keepIndent = engine.handleNewline(inBlock, inBlock.length);
      expect(keepIndent.text, 'repeat 10:\n  print "hi"\n  ');

      // Smart Enter on a blank indented line exits one indent level cleanly
      const blankIndented = 'repeat 10:\n  print "hi"\n  ';
      final exitBlock =
          engine.handleNewline(blankIndented, blankIndented.length);
      expect(exitBlock.text, 'repeat 10:\n  print "hi"\n\n');

      // Smart Enter after `return` dedents by 2 spaces
      const fnBody = 'f() -> int:\n  return 1';
      final dedent = engine.handleNewline(fnBody, fnBody.length);
      expect(dedent.text, 'f() -> int:\n  return 1\n');

      // Auto-dedent `else:` when typed inside an `if` block
      const elseTyped = 'if x > 0:\n  print 1\n  else:';
      final dedentedElse =
          engine.handleTypedColon(elseTyped, elseTyped.length);
      expect(dedentedElse, isNotNull);
      expect(dedentedElse!.text, 'if x > 0:\n  print 1\nelse:');

      // Smart Backspace snaps leading indentation to previous indent stop
      const fourSpaces = 'if a:\n    ';
      final bs = engine.handleBackspace(fourSpaces, fourSpaces.length);
      expect(bs, isNotNull);
      expect(bs!.text, 'if a:\n  ');

      // Block Tab indent & outdent (VS Code style)
      const block = 'a = 1\nb = 2';
      final indented = engine.handleTab(block, 0, block.length);
      expect(indented.text, '  a = 1\n  b = 2');
      final outdented = engine.handleTab(indented.text, 0, indented.text.length,
          outdent: true);
      expect(outdented.text, block);

      // Toggle `# ` line comment on & off
      final commented = engine.toggleLineComment(block, 0, block.length);
      expect(commented.text, '# a = 1\n# b = 2');
      final uncommented =
          engine.toggleLineComment(commented.text, 0, commented.text.length);
      expect(uncommented.text, block);

      await session.dispose();
    });
  });
}
