import 'ast.dart';

/// Visits [node] and every node it owns, parents before children.
void walkAst(Node node, void Function(Node node) visit) {
  visit(node);
  switch (node) {
    case Program(:final statements):
      _nodes(statements, visit);
    case FunctionDeclaration(
        :final parameters,
        :final body,
        :final expressionBody,
        :final annotations,
        :final typeParameters,
      ):
      _nodes(parameters, visit);
      _nodes(annotations, visit);
      _nodes(typeParameters, visit);
      _optional(expressionBody, visit);
      _nodes(body, visit);
    case Metadata(:final arguments):
      _nodes(arguments, visit);
    case Parameter(:final defaultValue):
      _optional(defaultValue, visit);
    case Binding(:final value):
      walkAst(value, visit);
    case IfStatement(:final condition, :final thenBody, :final elseBody):
      walkAst(condition, visit);
      _nodes(thenBody, visit);
      _nodes(elseBody, visit);
    case ForStatement(:final iterable, :final body):
      walkAst(iterable, visit);
      _nodes(body, visit);
    case ReturnStatement(:final value):
      _optional(value, visit);
    case ExpressionStatement(:final expression):
      walkAst(expression, visit);
    case Literal():
    case Identifier():
    case ThisExpression():
    case BreakStatement():
    case ContinueStatement():
    case RethrowStatement():
    case WildcardPattern():
    case SymbolExpression():
    case AliasDeclaration():
    case PartDirective():
    case TypeParameter():
      break;
    case UnaryExpression(:final operand):
      walkAst(operand, visit);
    case BinaryExpression(:final left, :final right):
      walkAst(left, visit);
      walkAst(right, visit);
    case ListExpression(:final elements):
      _nodes(elements, visit);
    case Argument(:final value):
      walkAst(value, visit);
    case CallExpression(:final callee, :final arguments):
      walkAst(callee, visit);
      _nodes(arguments, visit);
    case InterpolatedString(:final parts):
      _nodes(parts, visit);
    case WhileStatement(:final condition, :final body):
      walkAst(condition, visit);
      _nodes(body, visit);
    case LabelStatement(:final statement):
      walkAst(statement, visit);
    case ImportDeclaration(:final condition):
      _optional(condition, visit);
    case FieldDeclaration(:final initializer):
      _optional(initializer, visit);
    case PropertyDeclaration(
        :final getter,
        :final getterBody,
        :final setterBody,
      ):
      _optional(getter, visit);
      _nodes(getterBody, visit);
      _nodes(setterBody, visit);
    case ConstructorDeclaration(
        :final parameters,
        :final body,
        :final expressionBody,
      ):
      _nodes(parameters, visit);
      _nodes(body, visit);
      _optional(expressionBody, visit);
    case ClassCase(:final fields):
      _nodes(fields, visit);
    case ClassDeclaration(
        :final fields,
        :final methods,
        :final cases,
        :final annotations,
        :final requirements,
        :final constructors,
        :final properties,
        :final typeParameters,
      ):
      _nodes(fields, visit);
      _nodes(methods, visit);
      _nodes(cases, visit);
      _nodes(annotations, visit);
      _nodes(requirements, visit);
      _nodes(constructors, visit);
      _nodes(properties, visit);
      _nodes(typeParameters, visit);
    case IfLetStatement(:final value, :final thenBody, :final elseBody):
      walkAst(value, visit);
      _nodes(thenBody, visit);
      _nodes(elseBody, visit);
    case DeferStatement(:final expression):
      walkAst(expression, visit);
    case IfCaseStatement(:final scrutinee, :final pattern, :final body):
      walkAst(scrutinee, visit);
      walkAst(pattern, visit);
      _nodes(body, visit);
    case WhenStatement(:final condition, :final body):
      walkAst(condition, visit);
      _nodes(body, visit);
    case UsingStatement(:final value, :final body):
      walkAst(value, visit);
      _nodes(body, visit);
    case MemberAssignment(:final object, :final value):
      walkAst(object, visit);
      walkAst(value, visit);
    case RequireStatement(:final condition, :final message):
      walkAst(condition, visit);
      _optional(message, visit);
    case ExtensionDeclaration(:final methods, :final typeParameters):
      _nodes(methods, visit);
      _nodes(typeParameters, visit);
    case WatchStatement(:final value, :final body):
      walkAst(value, visit);
      _nodes(body, visit);
    case BatchStatement(:final body):
      _nodes(body, visit);
    case Lambda(:final parameters, :final expressionBody, :final body):
      _nodes(parameters, visit);
      _optional(expressionBody, visit);
      _nodes(body, visit);
    case MemberAccess(:final object):
      walkAst(object, visit);
    case IndexExpression(:final object, :final index):
      walkAst(object, visit);
      walkAst(index, visit);
    case MapExpression(:final keys, :final values):
      _nodes(keys, visit);
      _nodes(values, visit);
    case SetExpression(:final elements):
      _nodes(elements, visit);
    case RecordExpression(:final fields):
      _nodes(fields, visit);
    case RangeExpression(:final start, :final end):
      walkAst(start, visit);
      walkAst(end, visit);
    case AwaitExpression(:final operand):
      walkAst(operand, visit);
    case PropagateExpression(:final operand):
      walkAst(operand, visit);
    case SpreadElement(:final operand):
      walkAst(operand, visit);
    case NullAwareElement(:final value):
      walkAst(value, visit);
    case BindingPattern():
    case RestPattern():
      break;
    case LiteralPattern(:final literal):
      walkAst(literal, visit);
    case ConstructorPattern(:final fields):
      _nodes(fields, visit);
    case ListPattern(:final elements):
      _nodes(elements, visit);
    case MatchArm(:final pattern, :final body, :final guard):
      walkAst(pattern, visit);
      _optional(guard, visit);
      _nodes(body, visit);
    case TypedPattern():
      break;
    case DoExpression(:final body):
      _nodes(body, visit);
    case ResultStatement(:final value):
    case ThrowStatement(:final value):
    case YieldStatement(:final value):
      walkAst(value, visit);
    case CaptureExpression(:final body):
      walkAst(body, visit);
    case ConversionExpression(:final operand):
      walkAst(operand, visit);
    case WithExpression(:final receiver, :final values):
      walkAst(receiver, visit);
      _nodes(values, visit);
    case DotShorthand(:final arguments):
      _nodes(arguments, visit);
    case AssignExpression(:final value):
      walkAst(value, visit);
    case TestDeclaration(:final body):
      _nodes(body, visit);
    case CForStatement(:final init, :final condition, :final step, :final body):
      walkAst(init, visit);
      walkAst(condition, visit);
      _optional(step, visit);
      _nodes(body, visit);
    case RepeatStatement(:final body, :final condition):
      _nodes(body, visit);
      walkAst(condition, visit);
    case MatchStatement(:final value, :final arms):
      walkAst(value, visit);
      _nodes(arms, visit);
    case MapComprehension(
        :final condition,
        :final iterable,
        :final thenMap,
        :final elseMap,
      ):
      _optional(condition, visit);
      _optional(iterable, visit);
      walkAst(thenMap, visit);
      _optional(elseMap, visit);
    case IfExpression(:final condition, :final thenValue, :final elseValue):
      walkAst(condition, visit);
      walkAst(thenValue, visit);
      walkAst(elseValue, visit);
    case MatchExprArm(:final pattern, :final result, :final guard):
      walkAst(pattern, visit);
      _optional(guard, visit);
      walkAst(result, visit);
    case MatchExpression(:final value, :final arms):
      walkAst(value, visit);
      _nodes(arms, visit);
    case TryExpression(:final operand, :final fallback):
      walkAst(operand, visit);
      walkAst(fallback, visit);
    case TryStatement(:final body, :final catches, :final finallyBody):
      _nodes(body, visit);
      _nodes(catches, visit);
      _nodes(finallyBody, visit);
    case CatchClause(:final body):
      _nodes(body, visit);
    case DestructureStatement(:final pattern, :final value):
      walkAst(pattern, visit);
      walkAst(value, visit);
    case CollectionIf(
        :final condition,
        :final thenElements,
        :final elseElements
      ):
      walkAst(condition, visit);
      _nodes(thenElements, visit);
      _nodes(elseElements, visit);
    case CollectionFor(:final iterable, :final body):
      walkAst(iterable, visit);
      _nodes(body, visit);
    case MapPattern(:final keys, :final values):
      _nodes(keys, visit);
      _nodes(values, visit);
    case OrPattern(:final left, :final right):
    case AndPattern(:final left, :final right):
      walkAst(left, visit);
      walkAst(right, visit);
    case RelationalPattern(:final value):
      walkAst(value, visit);
    case CastPattern(:final inner):
    case NullCheckPattern(:final inner):
    case NullAssertPattern(:final inner):
      walkAst(inner, visit);
    case TypeApplication(:final callee):
      walkAst(callee, visit);
    case AwaitAllExpression(:final arms):
      _nodes(arms, visit);
    case AwaitIsolateExpression(:final call):
      walkAst(call, visit);
    case TaskGroupStatement(:final spawns):
      _nodes(spawns, visit);
    case AnnotationDeclaration(:final parameters):
      _nodes(parameters, visit);
    case ConfigDeclaration(:final value):
      _optional(value, visit);
  }
}

void _nodes(Iterable<Node>? nodes, void Function(Node) visit) {
  if (nodes == null) return;
  for (final node in nodes) {
    walkAst(node, visit);
  }
}

void _optional(Node? node, void Function(Node) visit) {
  if (node != null) walkAst(node, visit);
}
