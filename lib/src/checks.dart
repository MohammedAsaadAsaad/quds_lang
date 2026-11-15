/// Dart `package:test` checkers available as Quds prelude names.
class Check {
  const Check(this.name, this.parameters,
      {this.optional = 0, this.value = false, this.generic = false});

  /// Written Quds name. The generated call is `package:matcher`'s name.
  final String name;

  /// Positional parameter types. Empty for a matcher value.
  final List<String> parameters;

  /// How many trailing [parameters] may be omitted.
  final int optional;

  /// A matcher value such as `isTrue`, not a call.
  final bool value;

  /// `name<Type>()` with no positional arguments.
  final bool generic;

  String get signature {
    if (value) return name;
    if (generic && parameters.isEmpty) return '$name<Type>() -> dynamic';
    if (parameters.isEmpty) return '$name() -> dynamic';
    final required = parameters.length - optional;
    final parts = <String>[
      for (var i = 0; i < parameters.length; i++)
        i >= required ? '[${parameters[i]}]' : parameters[i],
    ];
    return '$name(${parts.join(', ')}) -> dynamic';
  }
}

const _object = 'Object?';
const _predicate = '(Object?) -> bool';
const _compare = '(Object?, Object?) -> int';
const _key = '(Object?) -> Object?';
const _pair = '(Object?, Object?) -> bool';

/// Matchers and related calls from `package:matcher`.
const checks = <Check>[
  Check('equals', [_object, 'int'], optional: 1),
  Check('same', [_object]),
  Check('isNot', [_object]),
  Check(
      'allOf', [_object, _object, _object, _object, _object, _object, _object],
      optional: 6),
  Check(
      'anyOf', [_object, _object, _object, _object, _object, _object, _object],
      optional: 6),
  Check('greaterThan', ['Object']),
  Check('greaterThanOrEqualTo', ['Object']),
  Check('lessThan', ['Object']),
  Check('lessThanOrEqualTo', ['Object']),
  Check('closeTo', ['num', 'num']),
  Check('inInclusiveRange', ['num', 'num']),
  Check('inExclusiveRange', ['num', 'num']),
  Check('inOpenClosedRange', ['num', 'num']),
  Check('inClosedOpenRange', ['num', 'num']),
  Check('contains', [_object]),
  Check('containsAll', [_object]),
  Check('containsAllInOrder', [_object]),
  Check('containsOnce', [_object]),
  Check('containsValue', [_object]),
  Check('containsPair', [_object, _object]),
  Check('isIn', [_object]),
  Check('orderedEquals', [_object]),
  Check('unorderedEquals', [_object]),
  Check('unorderedMatches', [_object]),
  Check('everyElement', [_object]),
  Check('anyElement', [_object]),
  Check('hasLength', [_object]),
  Check('startsWith', ['String']),
  Check('endsWith', ['String']),
  Check('matches', [_object]),
  Check('equalsIgnoringCase', ['String']),
  Check('equalsIgnoringWhitespace', ['String']),
  Check('stringContainsInOrder', [_object]),
  Check('predicate', [_predicate, 'String'], optional: 1),
  Check('throwsA', [_object]),
  Check('completion', [_object, 'String'], optional: 1),
  Check('prints', [_object]),
  Check('emits', [_object]),
  Check('emitsAnyOf', [_object]),
  Check('emitsError', [_object]),
  Check('emitsInOrder', [_object]),
  Check('emitsInAnyOrder', [_object]),
  Check('emitsThrough', [_object]),
  Check('mayEmit', [_object]),
  Check('mayEmitMultiple', [_object]),
  Check('neverEmits', [_object]),
  Check('isSortedUsing', [_compare]),
  Check('isSortedBy', [_key]),
  Check('isSortedByCompare', [_key, _compare]),
  Check('pairwiseCompare', [_object, _pair, 'String']),
  Check('isA', const [], generic: true),
  Check('isSorted', const [], generic: true),
  Check('isEmpty', const [], value: true),
  Check('isNotEmpty', const [], value: true),
  Check('isNull', const [], value: true),
  Check('isNotNull', const [], value: true),
  Check('isTrue', const [], value: true),
  Check('isFalse', const [], value: true),
  Check('isNaN', const [], value: true),
  Check('isNotNaN', const [], value: true),
  Check('anything', const [], value: true),
  Check('returnsNormally', const [], value: true),
  Check('isZero', const [], value: true),
  Check('isNonZero', const [], value: true),
  Check('isPositive', const [], value: true),
  Check('isNegative', const [], value: true),
  Check('isNonPositive', const [], value: true),
  Check('isNonNegative', const [], value: true),
  Check('isArgumentError', const [], value: true),
  Check('isConcurrentModificationError', const [], value: true),
  Check('isCyclicInitializationError', const [], value: true),
  Check('isException', const [], value: true),
  Check('isFormatException', const [], value: true),
  Check('isNoSuchMethodError', const [], value: true),
  Check('isNullThrownError', const [], value: true),
  Check('isRangeError', const [], value: true),
  Check('isStateError', const [], value: true),
  Check('isUnimplementedError', const [], value: true),
  Check('isUnsupportedError', const [], value: true),
  Check('isCastError', const [], value: true),
  Check('throwsArgumentError', const [], value: true),
  Check('throwsConcurrentModificationError', const [], value: true),
  Check('throwsCyclicInitializationError', const [], value: true),
  Check('throwsException', const [], value: true),
  Check('throwsFormatException', const [], value: true),
  Check('throwsNoSuchMethodError', const [], value: true),
  Check('throwsNullThrownError', const [], value: true),
  Check('throwsRangeError', const [], value: true),
  Check('throwsStateError', const [], value: true),
  Check('throwsUnimplementedError', const [], value: true),
  Check('throwsUnsupportedError', const [], value: true),
  Check('throws', const [], value: true),
  Check('completes', const [], value: true),
  Check('doesNotComplete', const [], value: true),
  Check('emitsDone', const [], value: true),
];
