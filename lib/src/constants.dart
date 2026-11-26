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
        ConstMap(
          :final keyType,
          :final valueType,
          :final keys,
          :final values
        ) =>
          'const <$keyType, $valueType>{${[
            for (var i = 0; i < keys.length; i++)
              '${keys[i].dartSource}: ${values[i].dartSource}'
          ].join(', ')}}',
        ConstSet(:final elementType, :final elements) =>
          'const <$elementType>{${elements.map((e) => e.dartSource).join(', ')}}',
        ConstObject(:final type, :final fields) =>
          'const $type(${fields.map((e) => e.dartSource).join(', ')})',
        ConstDuration(:final microseconds) => formatDartDuration(microseconds),
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
        (ConstMap a, ConstMap b) => a.keyType == b.keyType &&
            a.valueType == b.valueType &&
            _sameList(a.keys, b.keys) &&
            _sameList(a.values, b.values),
        (ConstSet a, ConstSet b) => a.elementType == b.elementType &&
            a.elements.length == b.elements.length &&
            _sameList(a.elements, b.elements),
        (ConstObject a, ConstObject b) =>
          a.type == b.type && _sameList(a.fields, b.fields),
        (ConstDuration a, ConstDuration b) => a.microseconds == b.microseconds,
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
        ConstMap(
          :final keyType,
          :final valueType,
          :final keys,
          :final values
        ) =>
          Object.hash(6, keyType, valueType, Object.hashAll(keys),
              Object.hashAll(values)),
        ConstSet(:final elementType, :final elements) =>
          Object.hash(7, elementType, Object.hashAll(elements)),
        ConstObject(:final type, :final fields) =>
          Object.hash(8, type, Object.hashAll(fields)),
        ConstDuration(:final microseconds) => Object.hash(9, microseconds),
      };

  @override
  String toString() => dartSource;
}

String formatDartDuration(int microseconds) {
  if (microseconds == 0) return 'Duration.zero';
  const usPerMs = 1000;
  const usPerSec = 1000000;
  const usPerMin = 60 * usPerSec;
  const usPerHour = 60 * usPerMin;
  const usPerDay = 24 * usPerHour;
  if (microseconds % usPerDay == 0) {
    return 'const Duration(days: ${microseconds ~/ usPerDay})';
  }
  if (microseconds % usPerHour == 0) {
    return 'const Duration(hours: ${microseconds ~/ usPerHour})';
  }
  if (microseconds % usPerMin == 0) {
    return 'const Duration(minutes: ${microseconds ~/ usPerMin})';
  }
  if (microseconds % usPerSec == 0) {
    return 'const Duration(seconds: ${microseconds ~/ usPerSec})';
  }
  if (microseconds % usPerMs == 0) {
    return 'const Duration(milliseconds: ${microseconds ~/ usPerMs})';
  }
  return 'const Duration(microseconds: $microseconds)';
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

class ConstMap extends ConstValue {
  ConstMap(this.keyType, this.valueType, this.keys, this.values);
  final String keyType, valueType;
  final List<ConstValue> keys, values;
}

class ConstSet extends ConstValue {
  ConstSet(this.elementType, this.elements);
  final String elementType;
  final List<ConstValue> elements;
}

class ConstObject extends ConstValue {
  ConstObject(this.type, this.fields);
  final String type;
  final List<ConstValue> fields;
}

class ConstDuration extends ConstValue {
  ConstDuration(this.microseconds);
  final int microseconds;
}

/// A const constructor invocation recorded while checking the call.
class ConstConstructor {
  const ConstConstructor(this.type, this.parameters,
      {this.requirements = const []});
  final String type;
  final List<Parameter> parameters;
  final List<Expression> requirements;
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
    required this.constConstructorOf,
    required this.fail,
  });

  final Map<Expression, ConstValue> constants;
  final ConstValue? Function(Identifier node) constantValueOf;
  final String? Function(Expression node) typeOf;
  final ConstConstructor? Function(CallExpression node) constConstructorOf;
  final Never Function(String message, Node node) fail;
  Map<String, ConstValue>? _bound;
  var _ephemeral = false;

  ConstValue evaluate(Expression node) {
    if (!_ephemeral) {
      final existing = constants[node];
      if (existing != null) return existing;
    }
    final value = switch (node) {
      Literal() => _literal(node),
      DurationLiteral(:final microseconds) => ConstDuration(microseconds),
      Identifier() => _identifier(node),
      UnaryExpression() => _unary(node),
      BinaryExpression() => _binary(node),
      ListExpression() => _list(node),
      MapExpression() => _map(node),
      SetExpression() => _set(node),
      CallExpression() => _call(node),
      _ => fail('const requires a compile-time constant', node),
    };
    if (!_ephemeral) constants[node] = value;
    return value;
  }

  /// Structural const-ness only. Does not evaluate, so a skipped operand can
  /// still be rejected when it is not a constant expression.
  void ensureConstant(Expression node) {
    switch (node) {
      case Literal() || DurationLiteral():
        return;
      case Identifier():
        if (_bound != null && _bound!.containsKey(node.name)) return;
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
      case MapExpression(:final keys, :final values):
        for (var i = 0; i < keys.length; i++) {
          ensureConstant(keys[i]);
          ensureConstant(values[i]);
        }
      case SetExpression(:final elements):
        for (final element in elements) {
          ensureConstant(element);
        }
      case CallExpression(:final arguments):
        final info = constConstructorOf(node);
        if (info == null) fail('const requires a compile-time constant', node);
        final supplied = <String>{};
        var positional = 0;
        for (final argument in arguments) {
          ensureConstant(argument.value);
          if (argument.name == null) {
            if (positional < info.parameters.length) {
              supplied.add(info.parameters[positional].name);
            }
            positional++;
          } else {
            supplied.add(argument.name!);
          }
        }
        for (final parameter in info.parameters) {
          if (supplied.contains(parameter.name)) continue;
          final fallback = parameter.defaultValue;
          if (fallback == null) {
            fail('const requires a compile-time constant', node);
          }
          ensureConstant(fallback);
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
    final bound = _bound?[node.name];
    if (bound != null) return bound;
    final value = constantValueOf(node);
    if (value == null) fail('const requires a compile-time constant', node);
    return value;
  }

  ConstValue _unary(UnaryExpression node) {
    final value = evaluate(node.operand);
    switch (node.operator) {
      case 'not':
        if (value is! ConstBool) {
          throw StateError('Unary not on ${value.runtimeType}');
        }
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
          ConstDuration(:final microseconds) => ConstDuration(-microseconds),
          _ => throw StateError('Unary - on ${value.runtimeType}'),
        };
      case '~':
        if (value is ConstInt) return ConstInt(~value.value);
        throw StateError('Unary ~ on ${value.runtimeType}');
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
      case '&' || '|' || '^' || '<<' || '>>' || '>>>':
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        if (left is ConstBool && right is ConstBool) {
          return ConstBool(switch (node.operator) {
            '&' => left.value & right.value,
            '|' => left.value | right.value,
            '^' => left.value ^ right.value,
            _ => throw StateError('Shift operands must be int'),
          });
        }
        if (left is! ConstInt || right is! ConstInt) {
          throw StateError('Bitwise operands must be int');
        }
        if ({'<<', '>>', '>>>'}.contains(node.operator) && right.value < 0) {
          fail('Shift count cannot be negative in a compile-time constant',
              node);
        }
        return ConstInt(switch (node.operator) {
          '&' => left.value & right.value,
          '|' => left.value | right.value,
          '^' => left.value ^ right.value,
          '<<' => left.value << right.value,
          '>>' => left.value >> right.value,
          _ => left.value >>> right.value,
        });
      case '+':
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        if (left is ConstString && right is ConstString) {
          return ConstString(left.value + right.value);
        }
        return _numeric(left, '+', right, node);
      case '*':
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        if (left is ConstString && right is ConstInt) {
          if (right.value < 0) fail('A repeat count cannot be negative', node);
          return ConstString(left.value * right.value);
        }
        if (left is ConstInt && right is ConstString) {
          if (left.value < 0) fail('A repeat count cannot be negative', node);
          return ConstString(right.value * left.value);
        }
        return _numeric(left, '*', right, node);
      default:
        final left = evaluate(node.left);
        final right = evaluate(node.right);
        return _numeric(left, node.operator, right, node);
    }
  }

  ConstValue _logical(BinaryExpression node,
      {required bool whenLeft, required bool result}) {
    final left = evaluate(node.left);
    if (left is! ConstBool) {
      throw StateError('Logical operand ${left.runtimeType}');
    }
    if (left.value == whenLeft) {
      ensureConstant(node.right);
      return ConstBool(result);
    }
    final right = evaluate(node.right);
    if (right is! ConstBool) {
      throw StateError('Logical operand ${right.runtimeType}');
    }
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

  ConstValue _map(MapExpression node) {
    final type = typeOf(node);
    if (type == null || !type.startsWith('Map<') || !type.endsWith('>')) {
      throw StateError('Missing map type for a const map');
    }
    final pair = _splitPair(type.substring(4, type.length - 1));
    final keys = <ConstValue>[];
    final values = <ConstValue>[];
    for (var i = 0; i < node.keys.length; i++) {
      keys.add(evaluate(node.keys[i]));
      values.add(evaluate(node.values[i]));
    }
    return ConstMap(pair.$1, pair.$2, keys, values);
  }

  ConstValue _set(SetExpression node) {
    final type = typeOf(node);
    if (type == null || !type.startsWith('Set<') || !type.endsWith('>')) {
      throw StateError('Missing set type for a const set');
    }
    return ConstSet(
      type.substring(4, type.length - 1),
      [for (final element in node.elements) evaluate(element)],
    );
  }

  ConstValue _call(CallExpression node) {
    final info = constConstructorOf(node);
    if (info == null) fail('const requires a compile-time constant', node);
    final values = List<ConstValue?>.filled(info.parameters.length, null);
    var positional = 0;
    for (final argument in node.arguments) {
      final value = evaluate(argument.value);
      if (argument.name == null) {
        if (positional >= values.length) {
          fail('const requires a compile-time constant', argument);
        }
        values[positional++] = value;
      } else {
        final index =
            info.parameters.indexWhere((item) => item.name == argument.name);
        if (index < 0) fail('const requires a compile-time constant', argument);
        values[index] = value;
      }
    }
    for (var i = 0; i < info.parameters.length; i++) {
      if (values[i] != null) continue;
      final fallback = info.parameters[i].defaultValue;
      if (fallback == null) {
        fail('const requires a compile-time constant', node);
      }
      values[i] = evaluate(fallback);
    }
    if (info.requirements.isNotEmpty) {
      final savedBound = _bound;
      final savedEphemeral = _ephemeral;
      _bound = {'value': values.first!};
      _ephemeral = true;
      try {
        for (final requirement in info.requirements) {
          final result = evaluate(requirement);
          if (result is! ConstBool || !result.value) {
            fail(
                'A wrapped value fails require and is not a compile-time constant',
                node);
          }
        }
      } finally {
        _bound = savedBound;
        _ephemeral = savedEphemeral;
      }
    }
    return ConstObject(info.type, [for (final value in values) value!]);
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
  if (left is ConstList ||
      right is ConstList ||
      left is ConstMap ||
      right is ConstMap ||
      left is ConstSet ||
      right is ConstSet ||
      left is ConstObject ||
      right is ConstObject) {
    return _canonical(left, right);
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
  if (left is ConstMap && right is ConstMap) {
    if (left.keyType != right.keyType ||
        left.valueType != right.valueType ||
        left.keys.length != right.keys.length) {
      return false;
    }
    for (var i = 0; i < left.keys.length; i++) {
      if (!_canonical(left.keys[i], right.keys[i]) ||
          !_canonical(left.values[i], right.values[i])) {
        return false;
      }
    }
    return true;
  }
  if (left is ConstSet && right is ConstSet) {
    if (left.elementType != right.elementType ||
        left.elements.length != right.elements.length) {
      return false;
    }
    for (var i = 0; i < left.elements.length; i++) {
      if (!_canonical(left.elements[i], right.elements[i])) return false;
    }
    return true;
  }
  if (left is ConstObject && right is ConstObject) {
    if (left.type != right.type || left.fields.length != right.fields.length) {
      return false;
    }
    for (var i = 0; i < left.fields.length; i++) {
      if (!_canonical(left.fields[i], right.fields[i])) return false;
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
    case 'Duration':
      if (value is! ConstDuration) _badConstShape(type, value);
    default:
      if (value is ConstList &&
          type.startsWith('List<') &&
          type.endsWith('>')) {
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
        return;
      }
      if (value is ConstMap && type.startsWith('Map<') && type.endsWith('>')) {
        final pair = _splitPair(type.substring(4, type.length - 1));
        if (value.keyType != pair.$1 || value.valueType != pair.$2) {
          _badConstShape(type, value);
        }
        for (final key in value.keys) {
          checkConstShape(pair.$1, key);
        }
        for (final item in value.values) {
          checkConstShape(pair.$2, item);
        }
        return;
      }
      if (value is ConstSet && type.startsWith('Set<') && type.endsWith('>')) {
        final element = type.substring(4, type.length - 1);
        if (value.elementType != element) _badConstShape(type, value);
        for (final item in value.elements) {
          checkConstShape(element, item);
        }
        return;
      }
      if (value is ConstObject && value.type == type) return;
      _badConstShape(type, value);
  }
}

(String, String) _splitPair(String inner) {
  var depth = 0;
  for (var i = 0; i < inner.length; i++) {
    final char = inner[i];
    if (char == '<' || char == '(') depth++;
    if (char == '>' || char == ')') depth--;
    if (char == ',' && depth == 0) {
      return (inner.substring(0, i).trim(), inner.substring(i + 1).trim());
    }
  }
  throw StateError('Missing comma in $inner');
}

Never _badConstShape(String type, ConstValue value) =>
    throw StateError('Constant value $value does not match static type $type');
