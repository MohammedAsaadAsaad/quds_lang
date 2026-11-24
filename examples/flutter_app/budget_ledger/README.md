# Quds Ledger (`budget_ledger`)

A modern, animated, cross-platform personal finance & budget ledger Flutter app written in **Quds**, consuming the standalone external pure-Quds package [`quds_ledger`](../quds_ledger).

## Highlights

- **External Quds package integration:** Imports `package:quds_ledger` for exact rational `Fraction`-backed `Money` math, multi-currency conversion (`USD`, `EUR`, `GBP`, `JOD`, `SAR`), `implicit`/`explicit` conversions (`to? Money`), `sealed type BudgetStatus`, `guard`/`Result` validation, and compile-time `@Json` snapshot export/import.
- **Modern animated UI:** Obsidian-emerald & warm gold palette with Dark/Light mode, smooth `TweenAnimationBuilder` balance counters, custom-painted animated donut spending chart, animated category budget progress bars, interactive desktop hover cards, responsive desktop NavigationRail + mobile NavigationBar, and live JSON backup/restore dialog.
- **Cross-platform:** Configured with platform runners and custom Quds Ledger app icons for **Android, Linux, Windows, Web, macOS, and iOS**.

## Build & Run

```bash
# 1. Test and build the external pure-Quds package
quds test ../quds_ledger/test/quds_ledger_test.quds
quds build --package ../quds_ledger

# 2. Build the Quds Flutter app sources into lib/*.dart
quds build --package .

# 3. Run or build with Flutter on any target platform
flutter pub get
flutter test
flutter run -d chrome      # Web
flutter run -d linux       # Linux
flutter run -d windows     # Windows
flutter run -d android     # Android
```
