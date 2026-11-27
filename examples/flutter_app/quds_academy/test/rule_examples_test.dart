import 'package:flutter_test/flutter_test.dart';
import 'package:quds_academy/platform/rule_examples.dart';
import 'package:quds_academy/quds_gen/src/catalog.dart';
import 'package:quds_academy/quds_gen/src/keywords.dart';

void main() {
  test('Every single Quds keyword (111) and lesson (12) has multiple live-executable examples that succeed on the Quds interpreter', () async {
    final keywords = keywordEntries();
    final allLessons = lessons();

    expect(keywords.length, greaterThanOrEqualTo(111));
    expect(allLessons.length, 12);

    final failures = <String>[];
    var executedCount = 0;

    // 1. Verify all 111+ keywords have >= 2 examples and every single one runs cleanly!
    for (final kw in keywords) {
      final list = examplesForKeyword(kw.name);
      if (list.length < 2) {
        failures.add(
          'Keyword "${kw.name}" has only ${list.length} examples (expected >= 2)',
        );
        continue;
      }
      for (var i = 0; i < list.length; i++) {
        final ex = list[i];
        final res = await runAcademyExampleCode(
          ex.code,
          file: 'kw_${kw.name}_$i.quds',
        );
        executedCount++;
        if (!res.succeeded) {
          failures.add(
            'Keyword "${kw.name}" example #$i ("${ex.titleEn}") FAILED: ${res.error}',
          );
        } else if (res.stdout.trim().isEmpty && res.value == null) {
          failures.add(
            'Keyword "${kw.name}" example #$i ("${ex.titleEn}") produced empty output',
          );
        }
      }
    }

    // 2. Verify all 12 lessons have >= 3 extra examples and every single one runs cleanly!
    for (final lesson in allLessons) {
      final list = examplesForLesson(lesson.id);
      if (list.length < 3) {
        failures.add(
          'Lesson "${lesson.id}" has only ${list.length} extra examples (expected >= 3)',
        );
        continue;
      }
      for (var i = 0; i < list.length; i++) {
        final ex = list[i];
        final res = await runAcademyExampleCode(
          ex.code,
          file: 'lesson_${lesson.id}_$i.quds',
        );
        executedCount++;
        if (!res.succeeded) {
          failures.add(
            'Lesson "${lesson.id}" example #$i ("${ex.titleEn}") FAILED: ${res.error}',
          );
        } else if (res.stdout.trim().isEmpty && res.value == null) {
          failures.add(
            'Lesson "${lesson.id}" example #$i ("${ex.titleEn}") produced empty output',
          );
        }
      }
    }

    // Print clear summary of verified examples
    // ignore: avoid_print
    print(
      'Verified $executedCount live Quds examples across ${keywords.length} rules + ${allLessons.length} lessons!',
    );
    expect(
      failures,
      isEmpty,
      reason: 'Failed examples (${failures.length}):\n${failures.join('\n')}',
    );
    expect(executedCount, greaterThanOrEqualTo(255));
  });

  test('Every Reference syntax panel and Lesson Playground handoff transfers a complete runnable example', () async {
    final keywords = keywordEntries();
    final allLessons = lessons();
    final failures = <String>[];

    // Verify all 111 Reference rules transfer complete runnable code (never broken syntax snippets!)
    for (final kw in keywords) {
      final transferred = runnableExampleForKeyword(kw.name, kw.example);
      final res = await runAcademyExampleCode(
        transferred,
        file: 'handoff_kw_${kw.name}.quds',
      );
      if (!res.succeeded) {
        failures.add('Reference handoff "${kw.name}" FAILED: ${res.error}');
      }
    }

    // Verify all 12 Lessons transfer complete runnable code (with Playground main() auto-invoke)
    for (final lesson in allLessons) {
      var transferred = runnableExampleForLesson(lesson.id, lesson.code);
      final mainDecl = RegExp(
        r'^main\(\s*\)\s*(async\s*)?:',
        multiLine: true,
      ).firstMatch(transferred);
      if (mainDecl != null &&
          !RegExp(
            r'^(?:await\s+)?main\(\s*\)\s*$',
            multiLine: true,
          ).hasMatch(transferred)) {
        transferred = mainDecl.group(1) != null
            ? '$transferred\nawait main()\n'
            : '$transferred\nmain()\n';
      }
      final res = await runAcademyExampleCode(
        transferred,
        file: 'handoff_lesson_${lesson.id}.quds',
      );
      if (!res.succeeded) {
        failures.add('Lesson handoff "${lesson.id}" FAILED: ${res.error}');
      }
    }

    expect(
      failures,
      isEmpty,
      reason: 'Broken Playground handoffs:\n${failures.join('\n')}',
    );
  });
}
