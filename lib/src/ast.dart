import 'source.dart';

sealed class Node {
  const Node(this.span);
  final SourceSpan span;
}

class Program extends Node {
  const Program(this.statements, super.span);
  final List<Statement> statements;
}

sealed class Statement extends Node {
  const Statement(super.span);
}

class FunctionDeclaration extends Statement {
  const FunctionDeclaration(this.name, this.parameters, this.returnType,
      this.body, this.expressionBody, super.span,
      {this.isAsync = false,
      this.annotations = const [],
      this.generator = '',
      this.visibility = '',
      this.isOperator = false,
      this.readonlyMethod = false});
  final String name;
  final List<Parameter> parameters;
  final String? returnType;
  final List<Statement>? body;
  final Expression? expressionBody;
  final bool isAsync;
  final List<String> annotations;

  /// Empty, `sync`, or `async`. A non-empty value means a generator.
  final String generator;

  /// Empty, `private`, or `protected`.
  final String visibility;
  final bool isOperator;
  final bool readonlyMethod;
}

class Parameter extends Node {
  const Parameter(this.name, this.type, this.mutable, super.span,
      {this.defaultValue, this.variadic = false, this.initializing = ''});
  final String name;
  final String type;
  final bool mutable;
  final Expression? defaultValue;

  /// `...name: Type` collects the remaining positional arguments as `List<Type>`.
  final bool variadic;

  /// Empty, `this`, or `super`. A non-empty value is an initializing formal.
  final String initializing;
}

enum BindingMode {
  inferred,
  mutable,
  constant,
  shadow,
  shadowMutable,
  lateFinal,
  lateMutable,
  state,
  computed
}

class Binding extends Statement {
  const Binding(
      this.name, this.mode, this.type, this.operator, this.value, super.span,
      {this.open = false});
  final String name;
  final BindingMode mode;
  final String? type;
  final String operator;
  final Expression value;

  /// A `late` binding that has no initializer yet.
  final bool open;
}

class IfStatement extends Statement {
  const IfStatement(this.condition, this.thenBody, this.elseBody, super.span);
  final Expression condition;
  final List<Statement> thenBody, elseBody;
}

class ForStatement extends Statement {
  const ForStatement(this.name, this.iterable, this.body, super.span,
      {this.awaiting = false});
  final String name;
  final Expression iterable;
  final List<Statement> body;
  final bool awaiting;
}

class ReturnStatement extends Statement {
  const ReturnStatement(this.value, super.span);
  final Expression? value;
}

class ExpressionStatement extends Statement {
  const ExpressionStatement(this.expression, super.span);
  final Expression expression;
}

sealed class Expression extends Node {
  const Expression(super.span);
}

class Literal extends Expression {
  const Literal(this.value, super.span);
  final Object? value;
}

class Identifier extends Expression {
  const Identifier(this.name, super.span);
  final String name;
}

class UnaryExpression extends Expression {
  const UnaryExpression(this.operator, this.operand, super.span);
  final String operator;
  final Expression operand;
}

class BinaryExpression extends Expression {
  const BinaryExpression(this.left, this.operator, this.right, super.span);
  final Expression left, right;
  final String operator;
}

class ListExpression extends Expression {
  const ListExpression(this.elements, super.span, {this.nullAware = const []});
  final List<Expression> elements;

  /// Parallel to [elements]. True omits a null element after one evaluation.
  final List<bool> nullAware;
}

class Argument extends Node {
  const Argument(this.name, this.value, super.span);
  final String? name;
  final Expression value;
}

class CallExpression extends Expression {
  const CallExpression(this.callee, this.arguments, super.span);
  final Expression callee;
  final List<Argument> arguments;
}

class InterpolatedString extends Expression {
  const InterpolatedString(this.parts, super.span);

  /// Alternating text literals and expressions, in evaluation order.
  final List<Expression> parts;
}

class WhileStatement extends Statement {
  const WhileStatement(this.condition, this.body, super.span);
  final Expression condition;
  final List<Statement> body;
}

class BreakStatement extends Statement {
  const BreakStatement(this.label, super.span);
  final String? label;
}

class ContinueStatement extends Statement {
  const ContinueStatement(this.label, super.span);
  final String? label;
}

class LabelStatement extends Statement {
  const LabelStatement(this.name, this.statement, super.span);
  final String name;
  final Statement statement;
}

class ImportDeclaration extends Statement {
  const ImportDeclaration(this.uri, this.prefix, super.span, {this.condition});
  final String uri;
  final String? prefix;

  /// `use uri when condition`. The import is kept only when the condition is true.
  final Expression? condition;
}

class PartDirective extends Statement {
  const PartDirective(this.uri, this.of, super.span);
  final String uri;
  final bool of;
}

class FieldDeclaration extends Node {
  const FieldDeclaration(this.name, this.type, this.mutable, this.requiredField,
      this.initializer, super.span,
      {this.visibility = ''});
  final String name;
  final String type;
  final bool mutable;
  final bool requiredField;
  final Expression? initializer;

  /// Empty, `private`, or `protected`.
  final String visibility;
}

class PropertyDeclaration extends Node {
  const PropertyDeclaration(this.name, this.type, this.getter, this.getterBody,
      this.setter, this.setterBody, super.span,
      {this.visibility = ''});
  final String name;
  final String type;
  final Expression? getter;
  final List<Statement>? getterBody;
  final String? setter;
  final List<Statement>? setterBody;
  final String visibility;
}

class ConstructorDeclaration extends Node {
  const ConstructorDeclaration(
      this.name, this.parameters, this.body, this.expressionBody, super.span,
      {this.factory = false, this.constant = false});
  final String? name;
  final List<Parameter> parameters;
  final List<Statement>? body;
  final Expression? expressionBody;
  final bool factory;
  final bool constant;
}

class ClassCase extends Node {
  const ClassCase(this.name, this.fields, super.span);
  final String name;
  final List<FieldDeclaration> fields;
}

class ClassDeclaration extends Statement {
  const ClassDeclaration(this.name, this.kind, this.fields, this.methods,
      this.cases, this.annotations, super.span,
      {this.superclass,
      this.mixins = const [],
      this.interfaces = const [],
      this.onType,
      this.modifiers = const [],
      this.requirements = const [],
      this.constructors = const [],
      this.properties = const []});
  final String name;

  /// `class`, `value`, `sealed`, `sealedType`, `mixin`, `mixinClass`, or `interface`.
  final String kind;
  final List<FieldDeclaration> fields;
  final List<FunctionDeclaration> methods;
  final List<ClassCase> cases;
  final List<String> annotations;
  final String? superclass;
  final List<String> mixins;
  final List<String> interfaces;
  final String? onType;
  final List<String> modifiers;
  final List<Expression> requirements;
  final List<ConstructorDeclaration> constructors;
  final List<PropertyDeclaration> properties;
}

class IfCaseStatement extends Statement {
  const IfCaseStatement(this.scrutinee, this.pattern, this.body, super.span);
  final Expression scrutinee;
  final Pattern pattern;
  final List<Statement> body;
}

class WhenStatement extends Statement {
  const WhenStatement(this.condition, this.body, super.span);
  final Expression condition;
  final List<Statement> body;
}

class UsingStatement extends Statement {
  const UsingStatement(this.name, this.value, this.body, super.span,
      {this.async = false});
  final String name;
  final Expression value;
  final List<Statement> body;
  final bool async;
}

class MemberAssignment extends Statement {
  const MemberAssignment(
      this.object, this.name, this.operator, this.value, super.span);
  final Expression object;
  final String name;
  final String operator;
  final Expression value;
}

class AliasDeclaration extends Statement {
  const AliasDeclaration(this.name, this.target, super.span);
  final String name;
  final String target;
}

class RequireStatement extends Statement {
  const RequireStatement(this.condition, super.span);
  final Expression condition;
}

class ExtensionDeclaration extends Statement {
  const ExtensionDeclaration(this.name, this.target, this.methods, super.span);
  final String? name;
  final String target;
  final List<FunctionDeclaration> methods;
}

class ThisExpression extends Expression {
  const ThisExpression(super.span);
}

class WatchStatement extends Statement {
  const WatchStatement(this.value, this.body, super.span);
  final Expression value;
  final List<Statement> body;
}

class Lambda extends Expression {
  const Lambda(this.parameters, this.expressionBody, this.body, super.span);
  final List<Parameter> parameters;
  final Expression? expressionBody;
  final List<Statement>? body;
}

class MemberAccess extends Expression {
  const MemberAccess(this.object, this.name, this.nullAware, super.span);
  final Expression object;
  final String name;
  final bool nullAware;
}

class IndexExpression extends Expression {
  const IndexExpression(this.object, this.index, super.span);
  final Expression object;
  final Expression index;
}

class MapExpression extends Expression {
  const MapExpression(this.keys, this.values, super.span);
  final List<Expression> keys, values;
}

class SetExpression extends Expression {
  const SetExpression(this.elements, super.span, {this.nullAware = const []});
  final List<Expression> elements;
  final List<bool> nullAware;
}

class RecordExpression extends Expression {
  const RecordExpression(this.fields, super.span);
  final List<Expression> fields;
}

class RangeExpression extends Expression {
  const RangeExpression(this.start, this.end, this.inclusive, super.span);
  final Expression start, end;
  final bool inclusive;
}

class AwaitExpression extends Expression {
  const AwaitExpression(this.operand, super.span);
  final Expression operand;
}

class PropagateExpression extends Expression {
  const PropagateExpression(this.operand, super.span);
  final Expression operand;
}

sealed class Pattern extends Node {
  const Pattern(super.span);
}

class WildcardPattern extends Pattern {
  const WildcardPattern(super.span);
}

class BindingPattern extends Pattern {
  const BindingPattern(this.name, super.span);
  final String name;
}

class LiteralPattern extends Pattern {
  const LiteralPattern(this.literal, super.span);
  final Expression literal;
}

class ConstructorPattern extends Pattern {
  const ConstructorPattern(this.typeName, this.fields, this.names, super.span);
  final String typeName;
  final List<Pattern> fields;
  final List<String?> names;
}

class ListPattern extends Pattern {
  const ListPattern(this.elements, super.span);
  final List<Pattern> elements;
}

class MatchArm extends Node {
  const MatchArm(this.pattern, this.body, super.span, {this.guard});
  final Pattern pattern;
  final List<Statement> body;
  final Expression? guard;
}

class TypedPattern extends Pattern {
  const TypedPattern(this.type, this.name, super.span);
  final String type;
  final String? name;
}

class DoExpression extends Expression {
  const DoExpression(this.body, super.span);
  final List<Statement> body;
}

class ResultStatement extends Statement {
  const ResultStatement(this.value, super.span);
  final Expression value;
}

class CaptureExpression extends Expression {
  const CaptureExpression(this.names, this.body, super.span);
  final List<String> names;
  final Expression body;
}

class ConversionExpression extends Expression {
  const ConversionExpression(this.operand, this.type, this.safe, super.span);
  final Expression operand;
  final String type;
  final bool safe;
}

class WithExpression extends Expression {
  const WithExpression(
      this.receiver, this.fields, this.values, this.nullAware, super.span);
  final Expression receiver;
  final List<String> fields;
  final List<Expression> values;
  final bool nullAware;
}

class DotShorthand extends Expression {
  const DotShorthand(this.name, this.arguments, super.span);
  final String name;
  final List<Argument>? arguments;
}

class AssignExpression extends Expression {
  const AssignExpression(this.name, this.operator, this.value, super.span);
  final String name, operator;
  final Expression value;
}

class TestDeclaration extends Statement {
  const TestDeclaration(
      this.kind, this.title, this.isAsync, this.body, super.span);
  final String kind, title;
  final bool isAsync;
  final List<Statement> body;
}

class CForStatement extends Statement {
  const CForStatement(
      this.init, this.condition, this.step, this.body, super.span);
  final Statement init;
  final Expression condition;
  final Expression? step;
  final List<Statement> body;
}

class RepeatStatement extends Statement {
  const RepeatStatement(this.body, this.condition, super.span);
  final List<Statement> body;
  final Expression condition;
}

class MatchStatement extends Statement {
  const MatchStatement(this.value, this.arms, super.span);
  final Expression value;
  final List<MatchArm> arms;
}

class SpreadElement extends Expression {
  const SpreadElement(this.operand, this.nullAware, super.span);
  final Expression operand;
  final bool nullAware;
}

class MapComprehension extends Expression {
  const MapComprehension(this.condition, this.name, this.iterable, this.thenMap,
      this.elseMap, super.span);
  final Expression? condition;
  final String? name;
  final Expression? iterable;
  final MapExpression thenMap;
  final MapExpression? elseMap;
}

class IfExpression extends Expression {
  const IfExpression(
      this.condition, this.thenValue, this.elseValue, super.span);
  final Expression condition, thenValue, elseValue;
}

class MatchExprArm extends Node {
  const MatchExprArm(this.pattern, this.result, super.span, {this.guard});
  final Pattern pattern;
  final Expression result;
  final Expression? guard;
}

class MatchExpression extends Expression {
  const MatchExpression(this.value, this.arms, super.span);
  final Expression value;
  final List<MatchExprArm> arms;
}

class TryExpression extends Expression {
  const TryExpression(this.operand, this.fallback, super.span);
  final Expression operand, fallback;
}

class TryStatement extends Statement {
  const TryStatement(this.body, this.catches, this.finallyBody, super.span);
  final List<Statement> body, finallyBody;
  final List<CatchClause> catches;
}

class CatchClause extends Node {
  const CatchClause(this.name, this.type, this.trace, this.body, super.span);
  final String name;
  final String? type, trace;
  final List<Statement> body;
}

class ThrowStatement extends Statement {
  const ThrowStatement(this.value, super.span);
  final Expression value;
}

class RethrowStatement extends Statement {
  const RethrowStatement(super.span);
}

class YieldStatement extends Statement {
  const YieldStatement(this.value, this.star, super.span);
  final Expression value;
  final bool star;
}

class DestructureStatement extends Statement {
  const DestructureStatement(this.pattern, this.value, super.span);
  final Pattern pattern;
  final Expression value;
}

class NullAwareElement extends Expression {
  const NullAwareElement(this.value, super.span);
  final Expression value;
}

class CollectionIf extends Expression {
  const CollectionIf(
      this.condition, this.thenElements, this.elseElements, super.span);
  final Expression condition;
  final List<Expression> thenElements;
  final List<Expression> elseElements;
}

class CollectionFor extends Expression {
  const CollectionFor(this.name, this.iterable, this.body, super.span);
  final String name;
  final Expression iterable;
  final List<Expression> body;
}
