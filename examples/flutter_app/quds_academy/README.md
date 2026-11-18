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
`test/core_test.quds` through `quds test`. Its three suites check SQL persistence
and injection-resistant bound values, all lesson demonstration outputs, and the
complete bilingual keyword catalog. It does not substitute for Flutter widget tests.

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
