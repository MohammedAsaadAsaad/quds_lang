/// Complete Executable Rule & Lesson Examples Registry for Quds Academy.
library;

import 'package:flutter/material.dart';

import 'rule_examples_model.dart';
import 'rule_examples_part1.dart';
import 'rule_examples_part2.dart';
import 'rule_examples_part3.dart';

export 'rule_examples_model.dart';

final Map<String, List<AcademyRuleExample>> allKeywordRuleExamples =
    Map<String, List<AcademyRuleExample>>.unmodifiable({
      ...ruleExamplesPart1,
      ...ruleExamplesPart2,
      ...ruleExamplesPart3,
    });

List<AcademyRuleExample> examplesForKeyword(String name) =>
    allKeywordRuleExamples[name] ?? const [];

List<AcademyRuleExample> examplesForLesson(String lessonId) =>
    lessonExtraExamples[lessonId] ?? const [];

int totalRuleExamplesCount() {
  var total = 0;
  for (final list in allKeywordRuleExamples.values) {
    total += list.length;
  }
  for (final list in lessonExtraExamples.values) {
    total += list.length;
  }
  return total;
}

/// Convenience widget builder callable cleanly from `lib/main.quds` for a
/// keyword/rule in the Reference screen.
Widget keywordRuleExamplesWidget({
  required String keyword,
  required bool arabic,
  required bool dark,
  required void Function(String code) onOpenPlayground,
}) {
  return AcademyRuleExamplesSection(
    scopeKey: 'kw_$keyword',
    examples: examplesForKeyword(keyword),
    arabic: arabic,
    dark: dark,
    onOpenPlayground: onOpenPlayground,
  );
}

/// Convenience widget builder callable cleanly from `lib/main.quds` for a
/// lesson in the Learn screen.
Widget lessonRuleExamplesWidget({
  required String lessonId,
  required bool arabic,
  required bool dark,
  required void Function(String code) onOpenPlayground,
}) {
  return AcademyRuleExamplesSection(
    scopeKey: 'lesson_$lessonId',
    examples: examplesForLesson(lessonId),
    arabic: arabic,
    dark: dark,
    onOpenPlayground: onOpenPlayground,
    headingAr: 'أمثلة إضافية تفاعلية بالمفسّر',
    headingEn: 'More Live Interpreter Examples',
  );
}
