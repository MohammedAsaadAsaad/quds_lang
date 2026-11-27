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
}
