# Quds

> **Status: Public Alpha (`0.1.0-alpha.1`)** — Statically typed, indentation-based general-purpose language that compiles to clean, readable Dart — with full Dart & Flutter interop, zero `build_runner` boilerplate, and an integrated CLI, LSP server, and debugger.

Quds keeps Dart's type safety, null safety, AOT/JIT/Web/Flutter ecosystem, and zero runtime overhead — while removing braces, semicolons, closing-parenthesis pyramids, and repetitive model boilerplate. The formal language design is version 1.2 in [the specification](docs/QUDS_LANGUAGE_SPECIFICATION.md); rule-by-rule certification progress is tracked in [LANGUAGE_READINESS.md](docs/LANGUAGE_READINESS.md) and [LANGUAGE_READINESS_AR.md](docs/LANGUAGE_READINESS_AR.md).

---

## Why Quds? Side-by-Side with Dart

### 1. Value Classes, `copyWith`, Equality & JSON — **6 lines vs ~45 lines**

In Dart, an immutable JSON model with structural equality and null-safe `copyWith` either requires ~45 lines of hand-written boilerplate or `freezed` + `json_serializable` + `build_runner`. In Quds, it is built into the language:

**Quds**
```quds
@Json
value class User:
  id: int required
  name: String required
  bio: String? = null
```

**Equivalent Dart (without codegen packages)**
```dart
class User {
  const User({required this.id, required this.name, this.bio});
  final int id;
  final String name;
  final String? bio;

  static const _sentinel = Object();
  User copyWith({int? id, String? name, Object? bio = _sentinel}) => User(
        id: id ?? this.id,
        name: name ?? this.name,
        bio: identical(bio, _sentinel) ? this.bio : bio as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'bio': bio};
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        bio: json['bio'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is User && other.id == id && other.name == name && other.bio == bio;

  @override
  int get hashCode => Object.hash(id, name, bio);
}
```

In Quds, `user.copyWith(bio: null)` explicitly clears `bio`, while `user.copyWith(name: "Noor")` keeps the existing `bio` — backed by `Optional<T>` and `missing` (`QUDS-083`).

---

### 2. Flutter Widget Trees Without Closing-Paren Pyramids (`QUDS-081`)

Every widget, constructor, or function accepts unified indentation blocks, and `children:` accepts direct `for`/`if` rows with built-in loop context (`$.index`, `$.iteration`, `$.isFirst`).

**Quds**
```quds
buildTransactions(context: BuildContext, items: List<String>) -> Widget:
  return Card:
    margin: EdgeInsets.all(16.0)
    child: Column:
      crossAxisAlignment: CrossAxisAlignment.start
      children:
        if items.isEmpty:
          Padding:
            padding: EdgeInsets.all(20.0)
            child: Text("No entries yet.")
        else:
          for title in items:
            ListTile:
              leading: CircleAvatar(child: Text("{$.iteration}"))
              title: Text(title)
```

**Equivalent Dart**
```dart
Widget buildTransactions(BuildContext context, List<String> items) {
  return Card(
    margin: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('No entries yet.'),
          )
        else
          for (var i = 0; i < items.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(items[i]),
            ),
      ],
    ),
  );
}
```

No `), ), ], ), );` ladders, no manual loop counter `var i = 0; i < items.length; i++`, and no semicolons.

---

### 3. Sealed Types, Safe Conversions (`to?`) & `Result` Propagation (`?`)

**Quds**
```quds
sealed type BudgetStatus:
  Healthy(remaining: double)
  Warning(remaining: double)
  Exceeded(overBy: double)

parsePositive(raw: String) -> Result<double, String>:
  amount = raw.trim() to? double
  guard amount != null and amount > 0.0 else:
    return Error("Enter a positive number")
  return Ok(amount)

statusLabel(status: BudgetStatus) -> String:
  return match status:
    Healthy(remaining: r): "On track ({r} left)"
    Warning(remaining: r): "Near limit ({r} left)"
    Exceeded(overBy: o): "Over budget by {o}"
```

**Equivalent Dart**
```dart
sealed class BudgetStatus {
  const BudgetStatus();
}
final class Healthy extends BudgetStatus {
  const Healthy({required this.remaining});
  final double remaining;
}
final class Warning extends BudgetStatus {
  const Warning({required this.remaining});
  final double remaining;
}
final class Exceeded extends BudgetStatus {
  const Exceeded({required this.overBy});
  final double overBy;
}

String statusLabel(BudgetStatus status) => switch (status) {
      Healthy(:final remaining) => 'On track ($remaining left)',
      Warning(:final remaining) => 'Near limit ($remaining left)',
      Exceeded(:final overBy) => 'Over budget by $overBy',
    };
```

---

### 4. Exact Rational Math, `retry` & Loop Context Out of the Box

```quds
use quds:math::number show Fraction, fraction

main():
  # Exact rational arithmetic — no floating-point drift (0.1 + 0.2 == 0.3)
  total = fraction(1, 10) + fraction(2, 10)
  print "{total.numerator}/{total.denominator}"   # 3/10

  # Built-in loop context: $.index (0-based), $.iteration (1-based), $.isFirst
  for city in ["Al-Quds", "Amman", "Cairo"]:
    prefix = "*" if $.isFirst else "-"
    print "{prefix} #{$.iteration}: {city}"

  # Built-in retry with $.iteration
  var tries = 0
  answer = retry 3:
    tries = $.iteration
    if tries < 2:
      throw "temporary network glitch"
    result "connected on attempt {tries}"
  print answer
```

### Summary: Where Quds Cuts Boilerplate

| Pattern | Dart | Quds |
| --- | --- | --- |
| Immutable `@Json` model + `==` + `hashCode` + `copyWith` | ~40–50 lines (or `build_runner`) | **4–6 lines** (`@Json` + `value class`) |
| `sealed` ADT hierarchy (3 variants) | ~20–25 lines of classes + constructors | **4 lines** (`sealed type`) |
| Nested Flutter widget trees | Deep `), ], ), );` pyramids | **Zero** closing-paren ladders (`Widget:` + `children:`) |
| Indexed `for-in` loops | Manual index / `.asMap().entries` | Built-in `$.index`, `$.iteration`, `$.isFirst` |
| Safe string/number parsing | `int.tryParse` / `double.tryParse` | Unified `expr to? Type` (and custom `cast`) |
| Immutable-by-default bindings | `final` on every local | `name = value` immutable; `var` only when mutable |

---

## Install

Install [Dart](https://dart.dev/get-dart) 3.3 or newer (below 4), then activate `quds` and install editor support:

```sh
# From pub.dev:
dart pub global activate quds

# Or directly from GitHub:
dart pub global activate --source git https://github.com/MohammedAsaadAsaad/quds_lang.git

# Install editor extensions (VS Code, Cursor, JetBrains, Claude Code):
quds install
```

The first command puts `quds` on your `PATH` (`~/.pub-cache/bin` on Linux/macOS, `%LOCALAPPDATA%\Pub\Cache\bin` on Windows). Open a new terminal if your shell does not see `quds` yet.

- `quds doctor` checks Dart, Flutter, the `quds` CLI, and editor integrations.
- `quds help` lists every command.

---

## Quick Start

### Console / CLI Program

```quds
square(n: int) -> int = n * n

main():
  name = "Quds"
  print "Hello {name}"
  print square(6)
```

```sh
quds run example/hello.quds
quds build example/hello.quds
quds test examples/flutter_app/quds_ledger/test/quds_ledger_test.quds
```

`quds build` writes clean, standalone Dart under `.dart_tool/quds/out/` (with source maps) without touching hand-written `.dart` files. Use `quds build --package` to generate publishable `lib/*.dart` files for dual Quds + Dart packages.

### Flutter App

```sh
quds create flutter hello
cd hello
quds run -d chrome    # or -d windows / -d linux / -d android
```

- `quds run -d <device>` compiles `lib/main.quds` and its dependencies (including external pure-Quds packages under `lib/quds_gen/_packages/`), prints live step-by-step progress, and launches Flutter with automatic Hot Reload on save (`r` reload, `R` hot restart, `q` quit).
- `quds build apk --release`, `quds build web`, `quds build windows`, and `quds build linux` compile Quds sources before invoking Flutter. See [project commands](docs/PROJECT_CLI.md) and [Flutter live updates](docs/FLUTTER_LIVE_UPDATES.md).

---

## Featured Examples

- **[Quds Ledger](examples/flutter_app/budget_ledger/README.md)** + **[`quds_ledger`](examples/flutter_app/quds_ledger/README.md)**: A cross-platform personal finance & multi-currency Flutter app written in paren-free Quds block syntax, importing a standalone pure-Quds external package (`package:quds_ledger`) powered by exact `Fraction` arithmetic, `@Json`, `sealed type`, `Result`, and custom `Money` casts.
- **[Quds Academy](examples/flutter_app/quds_academy/README.md)**: A bilingual Arabic/English interactive learning app written in Quds with animated Flutter screens and `sqlite_plus`.
- **[Calculator](examples/flutter_app/calculator)** & **[`examples/sum.quds`](examples/sum.quds)**: Focused Flutter and CLI starters.

---

## Editor & Debugging

The [`editors/vscode`](editors/vscode) extension provides:
- Syntax highlighting, format-on-save (`quds format`), and live compiler diagnostics.
- Hover types, keyword reference with Quds examples ([KEYWORD_REFERENCE.md](docs/KEYWORD_REFERENCE.md)), Dart-to-Quds tooltip previews ([DART_TOOLTIP_PREVIEWS.md](docs/DART_TOOLTIP_PREVIEWS.md)), completion (including `$.` loop context), Go to Definition (`F12`), and Rename.
- Integrated debugging (`F5`): `.quds` breakpoints, Flutter Hot Reload/Restart, **Quds: Show Generated Dart**, and live evaluation of `$` / `$.index` / `$.iteration` / `$.item` in Hover, Watch, and Debug Console.

---

## Development & Documentation

```sh
dart pub get --enforce-lockfile
dart format .
dart analyze
dart test -j 1 --reporter expanded
```

Key references:
- [Language Specification 1.2](docs/QUDS_LANGUAGE_SPECIFICATION.md) & [Approved Decisions](docs/LANGUAGE_DECISIONS.md)
- [Language Readiness Inventory](docs/LANGUAGE_READINESS.md), [Arabic Working Plan](docs/LANGUAGE_READINESS_AR.md), & [Open Limits](docs/OPEN_QUESTIONS.md)
- [Math Accuracy & API Coverage](docs/MATH_ACCURACY.md) / [MATH_COVERAGE.md](docs/MATH_COVERAGE.md)
- [Function Types & Nullability](docs/FUNCTION_NULLABILITY.md), [Generic Constraints](docs/GENERIC_CONSTRAINTS.md), [Provider Defaults](docs/QUDS_PROVIDER_DEFAULTS.md)
- [Validation Results](docs/VALIDATION.md) & [Environment Setup](docs/ENVIRONMENT.md)

## License

Quds is released under the [MIT License](LICENSE).
