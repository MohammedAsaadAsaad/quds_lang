import 'dart:convert';

import 'ast.dart';

/// A value computed for a supported Quds `const` initializer.
///
/// Equality here is representational: NaN equals NaN, and `-0.0` is distinct
/// from `0.0`. Language `==` and Dart const canonicalization are separate.
sealed class ConstValue {
  String get dartSource => switch (this) {
        ConstBool(:final value) => value ? 'true' : 'false',
        ConstInt(:final value) => '$value',
        ConstDouble(:final value) => _dartDouble(value),
        ConstString(:final value) => quoteDartString(value),
        ConstNull() => 'null',
        ConstList(:final elementType, :final elements) =>
          'const <$elementType>[${elements.map((e) => e.dartSource).join(', ')}]',
      };

  @override
  bool operator ==(Object other) => switch ((this, other)) {
        (ConstBool a, ConstBool b) => a.value == b.value,
        (ConstInt a, ConstInt b) => a.value == b.value,
        (ConstDouble a, ConstDouble b) => _sameDouble(a.value, b.value),
        (ConstString a, ConstString b) => a.value == b.value,
        (ConstNull(), ConstNull()) => true,
        (ConstList a, ConstList b) => a.elementType == b.elementType &&
            a.elements.length == b.elements.length &&
            _sameList(a.elements, b.elements),
        _ => false,
      };

  @override
  int get hashCode => switch (this) {
        ConstBool(:final value) => Object.hash(0, value),
        ConstInt(:final value) => Object.hash(1, value),
        ConstDouble(:final value) => Object.hash(2, _doubleHash(value)),
        ConstString(:final value) => Object.hash(3, value),
        ConstNull() => 4,
        ConstList(:final elementType, :final elements) =>
          Object.hash(5, elementType, Object.hashAll(elements)),
      };

  @override
  String toString() => dartSource;
}

class ConstBool extends ConstValue {
  ConstBool(this.value);
  final bool value;
}

class ConstInt extends ConstValue {
  ConstInt(this.value);
  final int value;
}

class ConstDouble extends ConstValue {
  ConstDouble(this.value);
  final double value;
}

class ConstString extends ConstValue {
  ConstString(this.value);
  final String value;
}

class ConstNull extends ConstValue {
  ConstNull();
}

class ConstList extends ConstValue {
  ConstList(this.elementType, this.elements);
  final String elementType;
  final List<ConstValue> elements;
}

/// Dart string literal, including escaped `$` so the output is not interpolated.
String quoteDartString(String value) =>
    jsonEncode(value).replaceAll(r'$', r'\$');

bool _sameList(List<ConstValue> left, List<ConstValue> right) {
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _sameDouble(double a, double b) {
  if (a.isNaN && b.isNaN) return true;
  if (a == 0 && b == 0) return a.isNegative == b.isNegative;
  return a == b;
}

int _doubleHash(double value) {
  if (value.isNaN) return 0x7ff80000;
  if (value == 0) return value.isNegative ? -1 : 0;
  return value.hashCode;
}

String _dartDouble(double value) {
  if (value.isNaN) return 'double.nan';
  if (value == double.infinity) return 'double.infinity';
  if (value == double.negativeInfinity) return 'double.negativeInfinity';
  if (value == 0 && value.isNegative) return '-0.0';
  final text = value.toString();
  if (text.contains('.') || text.contains('e') || text.contains('E')) {
    return text;
  }
  return '$text.0';
}

/// Evaluates the MVP-0 const subset.
///
/// Arithmetic uses the host Dart `int`/`double` operators. On the validated
/// native SDK those integers are 64-bit and wrap. `and`/`or` evaluate
/// left-to-right and skip the right operand when Dart short-circuits, but the
/// skipped operand must still be a constant expression.
class ConstantEvaluator {
  ConstantEvaluator({
    required this.constants,
    required this.constantValueOf,
    required this.typeOf,
    required this.fail,
  });

  final Map<Expression, ConstValue> constants;
  final ConstValue? Function(Identifier node) constantValueOf;
  final String? Function(Expression node) typeOf;
  final Never Function(String message, Node node) fail;

  ConstValue evaluate(Expression node) {
    final existing = constants[node];
    if (existing != null) return existing;
    final value = switch (node) {
      Literal() => _literal(node),
      Identifier() => _identifier(node),
      UnaryExpression() => _unary(node),
      BinaryExpression() => _binary(node),
      ListExpression() => _list(node),
      _ => fail('const requires a compile-time constant', node),
    };
    constants[node] = value;
    return value;
  }

  /// Structural const-ness only. Does not evaluate, so a skipped operand can
  /// still be rejected when it is not a constant expression.
  void ensureConstant(Expression node) {
    switch (node) {
      case Literal():
        return;
      case Identifier():
        if (constantValueOf(node) == null) {
          fail('const requires a compile-time constant', node);
        }
      case UnaryExpression(:final operand):
        ensureConstant(operand);
      case BinaryExpression(:final left, :final right):
        ensureConstant(left);
        ensureConstant(right);
      case ListExpression(:final elements):
        for (final element in elements) {
          ensureConstant(element);
        }
      default:
        fail('const requires a compile-time constant', node);
    }
  }

  ConstValue _literal(Literal node) => switch (node.value) {
        int value => ConstInt(value),
        double value => ConstDouble(value),
        bool value => ConstBool(value),
        String value => ConstString(value),
        null => ConstNull(),
        _ => throw StateError('Unknown literal'),
      };

  ConstValue _identifier(Identifier node) {
    final value = constantValueOf(node);
    if (value == null) fail('const requires a compile-time constant', node);
    return value;
  }

  ConstValue _unary(UnaryExpression node) {
    final value = evaluate(node.operand);
    switch (node.operator) {
      case 'not':
        if (value is! ConstBool)
          throw StateError('Unary not on ${value.runtimeType}');
        return ConstBool(!value.value);
      case '+':
        if (value is! ConstInt && value is! ConstDouble) {
          throw StateError('Unary + on ${value.runtimeType}');
        }
        return value;
      case '-':
        return switch (value) {
          ConstInt(:final value) => ConstInt(-value),
          ConstDouble(:final value) => ConstDouble(-value),
          _ => throw StateError('Unary - on ${value.runtimeType}'),
        };
      default:
        throw StateError('Unknown unary ${node.operator}');
    }
  }

  ConstValue _binary(BinaryExpression node) {
    switch (node.operator) {
      case 'and':
        return _logical(node, whenLeft: false, result: false);
      case 'or':
        return _logical(node, whenLeft: true, result: true);
      case '==' || '!=':
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        final equal = _languageEqual(left, right);
        return ConstBool(node.operator == '==' ? equal : !equal);
      case '+':
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        if (left is ConstString && right is ConstString) {
          return ConstString(left.value + right.value);
        }
        return _numeric(left, '+', right, node);
      default:
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        return _numeric(left, node.operator, right, node);
    }
  }

  ConstValue _logical(BinaryExpression node,
      {required bool whenLeft, required bool result}) {
    final left = evaluate(node.left);
    if (left is! ConstBool)
      throw StateError('Logical operand ${left.runtimeType}');
    if (left.value == whenLeft) {
      ensureConstant(node.right);
      return ConstBool(result);
    }
    final right = evaluate(node.right);
    if (right is! ConstBool)
      throw StateError('Logical operand ${right.runtimeType}');
    return right;
  }

  ConstValue _list(ListExpression node) {
    final type = typeOf(node);
    if (type == null || !type.startsWith('List<') || !type.endsWith('>')) {
      throw StateError('Missing list type for a const list');
    }
    return ConstList(
      type.substring(5, type.length - 1),
      [for (final element in node.elements) evaluate(element)],
    );
  }

  ConstValue _numeric(
      ConstValue left, String op, ConstValue right, Expression node) {
    final l = _num(left);
    final r = _num(right);
    try {
      final result = switch (op) {
        '+' => l + r,
        '-' => l - r,
        '*' => l * r,
        '/' => l / r,
        '%' => l % r,
        '<' => l < r,
        '<=' => l <= r,
        '>' => l > r,
        '>=' => l >= r,
        _ => throw StateError('Unknown operator $op'),
      };
      return switch (result) {
        int value => ConstInt(value),
        double value => ConstDouble(value),
        bool value => ConstBool(value),
        _ => throw StateError('Unexpected const result ${result.runtimeType}'),
      };
    } on UnsupportedError catch (error) {
      if (op == '%' && r is int && r == 0) {
        fail('Integer remainder by zero', node);
      }
      throw StateError('Unexpected constant failure: $error');
    }
  }

  num _num(ConstValue value) => switch (value) {
        ConstInt(:final value) => value,
        ConstDouble(:final value) => value,
        _ => throw StateError('Expected a number, found $value'),
      };
}

bool _languageEqual(ConstValue left, ConstValue right) {
  if (left is ConstList || right is ConstList) {
    return left is ConstList && right is ConstList && _canonical(left, right);
  }
  return switch ((left, right)) {
    (ConstInt a, ConstInt b) => a.value == b.value,
    (ConstInt a, ConstDouble b) => a.value == b.value,
    (ConstDouble a, ConstInt b) => a.value == b.value,
    (ConstDouble a, ConstDouble b) => a.value == b.value,
    (ConstString a, ConstString b) => a.value == b.value,
    (ConstBool a, ConstBool b) => a.value == b.value,
    (ConstNull(), ConstNull()) => true,
    _ => false,
  };
}

/// Dart const-list identity: same type arguments and canonical elements.
/// NaN matches NaN, and the sign of zero is significant. `int` and `double`
/// are different even when `1 == 1.0`.
bool _canonical(ConstValue left, ConstValue right) {
  if (left is ConstList && right is ConstList) {
    if (left.elementType != right.elementType ||
        left.elements.length != right.elements.length) {
      return false;
    }
    for (var i = 0; i < left.elements.length; i++) {
      if (!_canonical(left.elements[i], right.elements[i])) return false;
    }
    return true;
  }
  return switch ((left, right)) {
    (ConstDouble a, ConstDouble b) => _sameDouble(a.value, b.value),
    (ConstInt a, ConstInt b) => a.value == b.value,
    (ConstString a, ConstString b) => a.value == b.value,
    (ConstBool a, ConstBool b) => a.value == b.value,
    (ConstNull(), ConstNull()) => true,
    _ => false,
  };
}

void checkConstShape(String type, ConstValue value) {
  switch (type) {
    case 'int':
      if (value is! ConstInt) _badConstShape(type, value);
    case 'double':
      if (value is! ConstDouble) _badConstShape(type, value);
    case 'num':
      if (value is! ConstInt && value is! ConstDouble) {
        _badConstShape(type, value);
      }
    case 'bool':
      if (value is! ConstBool) _badConstShape(type, value);
    case 'String':
      if (value is! ConstString) _badConstShape(type, value);
    case 'Null':
      if (value is! ConstNull) _badConstShape(type, value);
    default:
      if (!type.startsWith('List<') ||
          !type.endsWith('>') ||
          value is! ConstList) {
        _badConstShape(type, value);
      }
      final element = type.substring(5, type.length - 1);
      if (value.elementType != element) _badConstShape(type, value);
      if (element == 'num') {
        for (final item in value.elements) {
          if (item is! ConstInt && item is! ConstDouble) {
            _badConstShape(element, item);
          }
        }
      } else {
        for (final item in value.elements) {
          checkConstShape(element, item);
        }
      }
  }
}

Never _badConstShape(String type, ConstValue value) =>
    throw StateError('Constant value $value does not match static type $type');
