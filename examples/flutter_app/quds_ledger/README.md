# quds_ledger

A pure-Quds personal finance and budget ledger package built with exact rational arithmetic (`Fraction` from `quds:math`), compile-time `@Json` serialization, `sealed type` budget health states, `implicit`/`explicit` `Money` conversions, and `guard`/`Result` validation.

Zero Flutter dependency — usable from Quds CLI apps, Dart libraries, and Flutter apps (see `../budget_ledger`).

## Commands

```bash
# Run Quds unit tests
quds test test/quds_ledger_test.quds

# Compile package libraries to Dart for external Dart/Flutter consumers
quds build --package .
```
