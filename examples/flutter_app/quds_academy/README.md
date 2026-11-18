# Quds Academy — أكاديمية قدس

An offline-first Arabic/English learning app whose interface, lesson content,
quizzes, keyword reference, and SQL operations are written in Quds.

## What is included

- Four responsive destinations: overview, lessons, keyword reference, progress.
- Twelve bilingual lessons with curated executable Quds demonstrations and quizzes.
- All 111 entries from the English keyword reference, with Arabic explanations.
- Arabic RTL and English LTR, light/dark appearance, bundled Cairo and JetBrains Mono.
- Animated transitions, progress indicators, hover/focus feedback and reduced-motion support.
- `sqlite_plus: 0.1.14` imported directly by Quds. Bound SQL parameters, progress,
  preferences, export/reopen and reset are exercised by executable Quds tests.
- Browser storage and native file persistence through small Dart platform adapters.
  If browser persistence is unavailable, the interface explicitly reports session storage.

The demonstrations are curated lessons, not an arbitrary code execution sandbox.

## Run with a Flutter SDK

From this directory, with Flutter and the repository's Dart compiler available:

```sh
flutter create --platforms=web --project-name quds_academy .
flutter pub get
python3 tool/sync_keywords.py --check
dart run tool/build.dart
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
flutter run -d chrome
```

Keep `lib/main.quds` as the editable entry point. The build helper generates
`lib/main.dart` and `lib/quds_gen/`; regenerate after changing Quds sources.
`flutter create` supplies the standard platform scaffolding. Additional native
platforms can be generated with the corresponding Flutter command and toolchains.

## Tests without Flutter

From the repository root, with Dart on PATH:

```sh
python3 examples/flutter_app/quds_academy/tool/check_core.py
```

This resolves the actual pub package in an isolated temporary project and runs
`test/core_test.quds` through `quds test`. Its five suites check SQL persistence
and injection-resistant bound values, all lesson demonstration outputs, and the
complete bilingual keyword catalog, category coverage and lossless syntax colors. It does not substitute for Flutter widget tests.

`test/widget_test.dart` covers desktop and mobile navigation, text scaling,
Arabic/English, quizzes, progress reopening, theme changes and storage retry.
Its storage test double replaces byte transport only; SQL still uses sqlite_plus.

## Source layout

| File | Responsibility |
| --- | --- |
| `lib/main.quds` | Flutter UI, state and interactions |
| `lib/src/catalog.quds` | Bilingual lessons, quizzes and executable demonstrations |
| `lib/src/progress.quds` | Direct sqlite_plus integration and all SQL |
| `lib/src/keywords.quds` | Generated bilingual keyword catalog |
| `assets/keywords_ar.json` | Maintained Arabic explanations |
| `tool/sync_keywords.py` | Synchronizes the shared English reference and Arabic catalog |
| `lib/platform/` | Dart browser/native byte persistence only |
| `tool/build.dart` | Quds compilation and Flutter bootstrap generation |

## Validation boundary

The implementation was developed against actual Flutter stable source APIs and
real sqlite_plus, not mock widget declarations. Flutter engine downloads from
`storage.googleapis.com` were denied by the managed environment's proxy (403).
Therefore widget tests, web build, browser rendering, screenshots and visual
quality have **not yet been verified** in this environment. Source compilation
and Quds tests are recorded separately in the repository validation document.

The host has been saved to an environment configuration draft; that does not
change the running environment. No environment was published as part of this work.
After network access is applied, run the complete Flutter commands above and fix
any widget, layout or platform issues before treating the application as released.

## Colored examples and guided keyword discovery

All lesson and reference code panels now render selectable colored Quds spans.
Keywords, types, function-call names, strings, numbers, operators and comments
have distinct colors on the dark code surface. Copy retains the exact original
source. The display-only scanner is written in `lib/src/code_colors.quds`; it
handles escaped/raw/triple strings and nested block comments. It tolerates
incomplete snippets and does not execute code or perform semantic analysis.
String interpolation stays in the string color. No editable code runner is added.

The reference opens with twelve bilingual category cards. Each card explains
its purpose, previews related words and shows its word count. Choose a category,
then a word to see its explanation and colored example. Return with **All
categories**. Search from the category overview searches the entire reference;
search inside a category narrows that category. Existing language/theme choices
continue to apply, and examples remain LTR in Arabic.

| Category | التصنيف |
| --- | --- |
| Bindings & scope | الارتباطات والنطاق |
| Decisions & loops | القرارات والحلقات |
| Values & operators | القيم والمعاملات |
| Types & composition | الأنواع والتركيب |
| Members & access | الأعضاء والوصول |
| Conversions & augmentation | التحويلات والإضافة |
| Libraries & interoperability | المكتبات والتكامل |
| Async & concurrency | العمليات غير المتزامنة والتزامن |
| Safety & resources | الأمان وإدارة الموارد |
| Patterns & queries | الأنماط والاستعلامات |
| State & events | الحالة والأحداث |
| Configuration & tests | الإعدادات والاختبارات |

`lib/src/reference_design.quds` owns the category descriptions and membership.
Every one of the 111 entries must appear exactly once. English explanations and
examples still come from the shared repository guide; Arabic explanations remain
in `assets/keywords_ar.json`. The `deferred` entry explicitly identifies its
current compiler limitation. Examples can omit imports/surrounding declarations,
which is stated in the detail panel rather than presented as runnable programs.

The five core Quds suites include exact catalog coverage and source preservation
for every reference example. Widget tests additionally describe category
navigation, filtered words and rich text spans; these need a working Flutter SDK.
