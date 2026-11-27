/// Lexical scope and binding management implementing Quds binding rules
/// (immutable-by-default, `var` mutable, `const`, QUDS-090 shadowing rules,
/// and QUDS-091 `capture(...)` snapshots).
library;

import '../ast.dart';
import '../source.dart';
import 'exceptions.dart';
import 'values.dart';

/// A single variable slot stored in a [QudsEnvironment].
class QudsSlot {
  QudsSlot({
    required this.name,
    required this.value,
    required this.mutable,
    this.isConst = false,
    this.declaredType,
    this.initialized = true,
  });

  final String name;
  Object? value;
  final bool mutable;
  final bool isConst;
  final String? declaredType;
  bool initialized;
}

/// Lexical scope frame for interpreted Quds execution.
class QudsEnvironment {
  QudsEnvironment({
    this.parent,
    this.isFunctionBoundary = false,
    this.isGlobal = false,
    this.allowTopLevelRebind = false,
  });

  final QudsEnvironment? parent;
  final bool isFunctionBoundary;
  final bool isGlobal;
  final bool allowTopLevelRebind;
  final Map<String, QudsSlot> _slots = {};

  /// All bindings defined directly in this frame.
  Map<String, QudsSlot> get localSlots => Map.unmodifiable(_slots);

  /// Snapshot of local variable values for debugger inspection.
  Map<String, Object?> snapshotLocals() => {
        for (final entry in _slots.entries)
          if (!entry.key.startsWith('__quds_')) entry.key: entry.value.value,
      };

  /// Returns true if [name] exists directly in this frame.
  bool containsLocal(String name) => _slots.containsKey(name);

  /// Resolves a slot walking up the lexical parent chain.
  QudsSlot? resolveSlot(String name) {
    final local = _slots[name];
    if (local != null) return local;
    return parent?.resolveSlot(name);
  }

  /// Resolves a slot strictly in enclosing scopes (excluding this frame).
  QudsSlot? resolveOuterSlot(String name) => parent?.resolveSlot(name);

  /// Reads the value of [name], throwing [QudsRuntimeException] if undefined.
  Object? get(String name, SourceSpan span) {
    final slot = resolveSlot(name);
    if (slot == null) {
      throw QudsRuntimeException(
        'Undefined variable `$name`.',
        span,
        code: 'E200',
      );
    }
    if (!slot.initialized) {
      throw QudsRuntimeException(
        'Late variable `$name` was read before initialization.',
        span,
        code: 'E204',
      );
    }
    return slot.value;
  }

  /// Defines a new binding directly in this frame (used for builtins,
  /// parameters, imports, and host injections).
  void define(
    String name,
    Object? value, {
    bool mutable = false,
    bool isConst = false,
    String? declaredType,
    bool initialized = true,
  }) {
    _slots[name] = QudsSlot(
      name: name,
      value: value,
      mutable: mutable,
      isConst: isConst,
      declaredType: declaredType,
      initialized: initialized,
    );
  }

  /// Registers a function declaration, supporting QUDS-085 overloads when
  /// multiple functions share the same name with distinct parameter signatures.
  ///
  /// Throws `E201` when a duplicate signature is declared in the same scope
  /// unless [allowReplace] is explicitly enabled (for cross-run REPL rebinding).
  void defineFunction(QudsUserFunction fn, {bool allowReplace = false}) {
    final existing = _slots[fn.name];
    if (existing == null) {
      define(fn.name, fn);
      return;
    }
    final current = existing.value;
    if (current is QudsUserFunction) {
      if (sameParameterShape(current.parameters, fn.parameters)) {
        if (allowReplace) {
          existing.value = fn;
        } else {
          throw QudsRuntimeException(
            'Duplicate function or unsupported overload: `${fn.name}` '
            '(already defined on line ${current.span.line}).',
            fn.span,
            code: 'E201',
          );
        }
      } else {
        existing.value = QudsOverloadSet(fn.name, [current, fn]);
      }
      return;
    }
    if (current is QudsOverloadSet) {
      final idx = current.overloads
          .indexWhere((o) => sameParameterShape(o.parameters, fn.parameters));
      if (idx >= 0) {
        if (allowReplace) {
          current.overloads[idx] = fn;
        } else {
          throw QudsRuntimeException(
            'Duplicate function or unsupported overload: `${fn.name}` '
            '(already defined on line ${current.overloads[idx].span.line}).',
            fn.span,
            code: 'E201',
          );
        }
      } else {
        current.overloads.add(fn);
      }
      return;
    }
    if (!allowReplace && !_isBuiltinSlot(fn.name, existing)) {
      throw QudsRuntimeException(
        'Duplicate name: `${fn.name}` is already defined in this scope.',
        fn.span,
        code: 'E201',
      );
    }
    define(fn.name, fn);
  }

  /// Handles Quds `Binding` statements (`=`, `var`, `const`, `shadow`, `late`,
  /// and compound assignments) following QUDS-090 semantics.
  void bind(
    String name,
    BindingMode mode,
    Object? value,
    SourceSpan span, {
    String? declaredType,
    bool open = false,
    bool allowMutation = true,
  }) {
    final isShadow =
        mode == BindingMode.shadow || mode == BindingMode.shadowMutable;
    final wantsMutable = mode == BindingMode.mutable ||
        mode == BindingMode.shadowMutable ||
        mode == BindingMode.lateMutable ||
        mode == BindingMode.state;

    if (wantsMutable && !allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Mutable bindings (`var $name`) are disabled by the active execution policy.',
        span,
      );
    }

    // Explicit `shadow` always creates a new binding in the current scope.
    if (isShadow) {
      _slots[name] = QudsSlot(
        name: name,
        value: value,
        mutable: wantsMutable,
        declaredType: declaredType,
        initialized: !open,
      );
      return;
    }

    // Explicit `var` / `const` / `late` declaration introduces a new local binding.
    if (mode == BindingMode.mutable ||
        mode == BindingMode.constant ||
        mode == BindingMode.lateFinal ||
        mode == BindingMode.lateMutable ||
        mode == BindingMode.state ||
        mode == BindingMode.computed) {
      if (_slots.containsKey(name) && !(isGlobal && allowTopLevelRebind)) {
        throw QudsRuntimeException(
          'Binding `$name` is already defined in this scope.',
          span,
          code: 'E201',
        );
      }
      if (!isGlobal && resolveOuterSlot(name) != null) {
        // QUDS-090: unintentional shadowing inside nested scopes requires `shadow`.
        final outer = resolveOuterSlot(name)!;
        // Allow declaring local names that happen to match top-level builtins/functions
        // only if the outer slot is NOT a user variable in the same function?
        // In Quds, shadowing an outer local variable requires `shadow`.
        if (!_isBuiltinSlot(name, outer)) {
          throw QudsRuntimeException(
            'Cannot shadow outer binding `$name` without `shadow`.',
            span,
            code: 'E203',
          );
        }
      }
      _slots[name] = QudsSlot(
        name: name,
        value: value,
        mutable: wantsMutable,
        isConst: mode == BindingMode.constant,
        declaredType: declaredType,
        initialized: !open,
      );
      return;
    }

    // `BindingMode.inferred` (`name = value`):
    // 1. If `name` already exists in current or enclosing scope:
    final existing = resolveSlot(name);
    if (existing != null && !_isBuiltinSlot(name, existing)) {
      if (!existing.initialized) {
        existing.value = value;
        existing.initialized = true;
        return;
      }
      if (existing.mutable) {
        if (!allowMutation) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.featureDisabled,
            'Mutation of `$name` is disabled by the active execution policy.',
            span,
          );
        }
        existing.value = value;
        return;
      }
      if (isGlobal && allowTopLevelRebind && _slots.containsKey(name)) {
        _slots[name] = QudsSlot(
          name: name,
          value: value,
          mutable: false,
          declaredType: declaredType ?? existing.declaredType,
        );
        return;
      }
      throw QudsRuntimeException(
        'Cannot reassign immutable binding `$name`. Use `var` to make it mutable or `shadow` to shadow it.',
        span,
        code: 'E202',
      );
    }

    // 2. Otherwise define a new immutable binding in this scope.
    _slots[name] = QudsSlot(
      name: name,
      value: value,
      mutable: false,
      declaredType: declaredType,
      initialized: !open,
    );
  }

  /// Updates an existing mutable binding (used by `AssignExpression` and
  /// compound assignments like `x += 1`).
  void assignExisting(
    String name,
    Object? value,
    SourceSpan span, {
    bool allowMutation = true,
  }) {
    final slot = resolveSlot(name);
    if (slot == null) {
      throw QudsRuntimeException(
        'Undefined variable `$name`.',
        span,
        code: 'E200',
      );
    }
    if (!slot.initialized) {
      slot.value = value;
      slot.initialized = true;
      return;
    }
    if (!slot.mutable) {
      throw QudsRuntimeException(
        'Cannot reassign immutable binding `$name`.',
        span,
        code: 'E202',
      );
    }
    if (!allowMutation) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.featureDisabled,
        'Mutation of `$name` is disabled by the active execution policy.',
        span,
      );
    }
    slot.value = value;
  }

  /// Creates a child lexical scope.
  QudsEnvironment child({bool isFunctionBoundary = false}) => QudsEnvironment(
        parent: this,
        isFunctionBoundary: isFunctionBoundary,
        allowTopLevelRebind: allowTopLevelRebind,
      );

  /// Creates a snapshot environment for QUDS-091 `capture(a, b)`.
  QudsEnvironment captureSnapshot(List<String> names, SourceSpan span) {
    final snap = QudsEnvironment(parent: this);
    for (final name in names) {
      final val = get(name, span);
      snap.define(name, val, mutable: false);
    }
    return snap;
  }

  /// Removes all user bindings (used by `QudsSession.clear()`).
  void clearAll() => _slots.clear();

  /// Removes a single binding if present.
  bool removeLocal(String name) => _slots.remove(name) != null;

  bool _isBuiltinSlot(String name, QudsSlot slot) =>
      slot.value is QudsNativeFunction ||
      slot.value is QudsClass ||
      slot.value is QudsNamespace ||
      name == 'missing';

  /// Returns true when two function parameter lists have the same overload
  /// signature according to QUDS-085 (matching `semantics.dart:sameSignature`).
  static bool sameParameterShape(List<Parameter> a, List<Parameter> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].kind != b[i].kind ||
          (a[i].isNamed && a[i].name != b[i].name) ||
          a[i].variadic != b[i].variadic) {
        return false;
      }
      if (a[i].type != b[i].type) return false;
    }
    return true;
  }
}
