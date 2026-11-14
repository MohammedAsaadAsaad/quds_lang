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
      this.annotations = const <Metadata>[],
      this.generator = '',
      this.visibility = '',
      this.isOperator = false,
      this.readonlyMethod = false,
      this.isStatic = false,
      this.typeParameters = const [],
      this.documentation});
  final String name;
  final List<Parameter> parameters;
  final List<TypeParameter> typeParameters;
  final String? returnType;
  final List<Statement>? body;
  final Expression? expressionBody;
  final bool isAsync;
  final List<Metadata> annotations;

  /// Empty, `sync`, or `async`. A non-empty value means a generator.
  final String generator;

  /// Empty, `private`, or `protected`.
  final String visibility;
  final bool isOperator;
  final bool readonlyMethod;
  final bool isStatic;

  /// `#` or `///` lines immediately above this declaration.
  final String? documentation;
}

class Metadata extends Node {
  const Metadata(this.name, this.arguments, super.span);
  final String name;
  final List<Argument> arguments;
}

bool hasAnnotation(List<Metadata> notes, String name) =>
    notes.any((note) => note.name == name);

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
      {this.awaiting = false, this.index, this.step, this.elseBody = const []});
  final String name;

  /// The index in `for index, name in`, or the first field of a pair.
  final String? index;
  final Expression iterable;
  final List<Statement> body;
  final bool awaiting;

  /// The stride in `for name in range step value`.
  final Expression? step;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
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

/// `operand is Type`, `operand is! Type`, or `operand as Type`.
class TypeTestExpression extends Expression {
  const TypeTestExpression(this.operand, this.operator, this.type, super.span);
  final Expression operand;
  final String operator;
  final String type;
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
  const WhileStatement(this.condition, this.body, super.span,
      {this.letName, this.pattern, this.elseBody = const []});
  final Expression condition;
  final List<Statement> body;

  /// Set when the condition is `let name = expr`. [condition] is that expr.
  final String? letName;

  /// Set when the condition is `expr is pattern`. [condition] is that expr.
  final Pattern? pattern;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
}

/// A single statement guarded by a trailing `if`. The condition runs first.
class GuardedStatement extends Statement {
  const GuardedStatement(this.statement, this.condition, super.span,
      {this.letName, this.pattern, this.alternate});
  final Statement statement;
  final Expression condition;
  final String? letName;
  final Pattern? pattern;

  /// The value used when the condition does not hold. It fills the same slot.
  final Expression? alternate;
}

/// A `for`, `while`, or `repeat` used as a value. `break expr` supplies it.
class LoopExpression extends Expression {
  const LoopExpression(this.loop, this.fallback, super.span);
  final Statement loop;

  /// The value when the loop finishes without `break`. Null means a null result.
  final Expression? fallback;
}

/// Names bound once, left to right, before [value]. They do not escape.
class WhereExpression extends Expression {
  const WhereExpression(this.value, this.bindings, super.span,
      {this.block = false});
  final Expression value;
  final List<Binding> bindings;

  /// True when the bindings occupy an indented block.
  final bool block;
}

/// `a, b = b, a` or `name, age = person`. Every right-hand value runs first.
class ParallelAssignment extends Statement {
  const ParallelAssignment(this.targets, this.values, super.span);
  final List<Pattern> targets;
  final List<Expression> values;
}

class BreakStatement extends Statement {
  const BreakStatement(this.label, super.span, {this.value});
  final String? label;

  /// The value of `break expr` inside a loop that is itself an expression.
  final Expression? value;
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
  const ImportDeclaration(this.uri, this.prefix, super.span,
      {this.condition,
      this.export = false,
      this.show = const [],
      this.hide = const []});
  final String uri;
  final String? prefix;

  /// `use uri when condition`. The import is kept only when the condition is true.
  final Expression? condition;

  /// `export uri` re-exports the library and does not import those names here.
  final bool export;

  /// `show a, b` keeps only these names. Empty means every public name.
  final List<String> show;

  /// `hide a, b` drops these names. Ignored when [show] is not empty.
  final List<String> hide;
}

class PartDirective extends Statement {
  const PartDirective(this.uri, this.of, super.span);
  final String uri;
  final bool of;
}

class FieldDeclaration extends Node {
  const FieldDeclaration(this.name, this.type, this.mutable, this.requiredField,
      this.initializer, super.span,
      {this.visibility = '', this.isStatic = false, this.isConst = false});
  final String name;
  final String type;
  final bool mutable;
  final bool requiredField;
  final Expression? initializer;

  /// Empty, `private`, or `protected`.
  final String visibility;
  final bool isStatic;
  final bool isConst;
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

class TypeParameter extends Node {
  const TypeParameter(this.name, super.span, {this.variance = '', this.bound});
  final String name;

  /// Empty, `in`, or `out`.
  final String variance;
  final String? bound;
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
      this.properties = const [],
      this.typeParameters = const [],
      this.documentation});
  final String name;

  /// `class`, `value`, `sealed`, `sealedType`, `mixin`, `mixinClass`, or `interface`.
  final String kind;
  final List<FieldDeclaration> fields;
  final List<FunctionDeclaration> methods;
  final List<ClassCase> cases;
  final List<Metadata> annotations;
  final String? superclass;
  final List<String> mixins;
  final List<String> interfaces;
  final String? onType;
  final List<String> modifiers;
  final List<Expression> requirements;
  final List<ConstructorDeclaration> constructors;
  final List<PropertyDeclaration> properties;
  final List<TypeParameter> typeParameters;

  /// `#` or `///` lines immediately above this declaration.
  final String? documentation;
}

class IfLetStatement extends Statement {
  const IfLetStatement(
      this.name, this.value, this.thenBody, this.elseBody, super.span);
  final String name;
  final Expression value;
  final List<Statement> thenBody, elseBody;
}

class DeferStatement extends Statement {
  const DeferStatement(this.expression, super.span);
  final Expression expression;
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
  const AliasDeclaration(this.name, this.target, super.span,
      {this.documentation});
  final String name;
  final String target;

  /// `#` or `///` lines immediately above this declaration.
  final String? documentation;
}

class RequireStatement extends Statement {
  const RequireStatement(this.condition, super.span,
      {this.message, this.kind = 'require'});
  final Expression condition;
  final Expression? message;

  /// `require`, `check`, or `assert`.
  final String kind;
}

class ExtensionDeclaration extends Statement {
  const ExtensionDeclaration(this.name, this.target, this.methods, super.span,
      {this.typeParameters = const []});
  final String? name;
  final String target;
  final List<FunctionDeclaration> methods;
  final List<TypeParameter> typeParameters;
}

class ThisExpression extends Expression {
  const ThisExpression(super.span);
}

class WatchStatement extends Statement {
  const WatchStatement(this.value, this.body, super.span);
  final Expression value;
  final List<Statement> body;
}

class BatchStatement extends Statement {
  const BatchStatement(this.body, super.span);
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

/// `text[1..]`, `text[..<n]`, and `items[1..3]`. A missing start is 0. A
/// missing end runs through the last element. [inclusive] is `..`; `..<` is
/// exclusive.
class SliceExpression extends Expression {
  const SliceExpression(
      this.object, this.start, this.end, this.inclusive, super.span);
  final Expression object;
  final Expression? start;
  final Expression? end;
  final bool inclusive;
}

/// `a <= b < c`. Every operand runs once, from left to right.
class ChainComparison extends Expression {
  const ChainComparison(this.operands, this.operators, super.span);
  final List<Expression> operands;
  final List<String> operators;
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
  const BindingPattern(this.name, super.span, {this.shadow = false});
  final String name;
  final bool shadow;
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
  const TypedPattern(this.type, this.name, super.span, {this.shadow = false});
  final String type;
  final String? name;
  final bool shadow;
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
      this.init, this.condition, this.step, this.body, super.span,
      {this.elseBody = const []});
  final Statement init;
  final Expression condition;
  final Expression? step;
  final List<Statement> body;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
}

class RepeatStatement extends Statement {
  const RepeatStatement(this.body, this.condition, super.span,
      {this.count, this.elseBody = const []});
  final List<Statement> body;

  /// The condition of `repeat: ... while condition`.
  final Expression? condition;

  /// The count of `repeat count:`.
  final Expression? count;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
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
  const CollectionFor(this.name, this.iterable, this.body, super.span,
      {this.filter, this.index});
  final String name;

  /// The index in `for index, name in`, or the first field of a pair.
  final String? index;
  final Expression iterable;
  final List<Expression> body;
  final Expression? filter;
}

class MapPattern extends Pattern {
  const MapPattern(this.keys, this.values, super.span);
  final List<Expression> keys;
  final List<Pattern> values;
}

class RestPattern extends Pattern {
  const RestPattern(this.name, super.span, {this.shadow = false});
  final String? name;
  final bool shadow;
}

class OrPattern extends Pattern {
  const OrPattern(this.left, this.right, super.span);
  final Pattern left, right;
}

class AndPattern extends Pattern {
  const AndPattern(this.left, this.right, super.span);
  final Pattern left, right;
}

class RelationalPattern extends Pattern {
  const RelationalPattern(this.operator, this.value, super.span);
  final String operator;
  final Expression value;
}

class CastPattern extends Pattern {
  const CastPattern(this.inner, this.type, super.span);
  final Pattern inner;
  final String type;
}

class NullCheckPattern extends Pattern {
  const NullCheckPattern(this.inner, super.span);
  final Pattern inner;
}

class NullAssertPattern extends Pattern {
  const NullAssertPattern(this.inner, super.span);
  final Pattern inner;
}

class TypeApplication extends Expression {
  const TypeApplication(this.callee, this.arguments, super.span);
  final Expression callee;
  final List<String> arguments;
}

class AwaitAllExpression extends Expression {
  const AwaitAllExpression(this.arms, super.span);
  final List<Expression> arms;
}

class AwaitIsolateExpression extends Expression {
  const AwaitIsolateExpression(this.call, super.span);
  final Expression call;
}

class SymbolExpression extends Expression {
  const SymbolExpression(this.text, super.span);
  final String text;
}

class TaskGroupStatement extends Statement {
  const TaskGroupStatement(this.children, super.span);

  /// Each child is a spawned expression or a nested task group, in source order.
  final List<Node> children;
}

class AnnotationDeclaration extends Statement {
  const AnnotationDeclaration(this.name, this.parameters, super.span);
  final String name;
  final List<Parameter> parameters;
}

class ConfigDeclaration extends Statement {
  const ConfigDeclaration(
      this.name, this.type, this.value, this.secret, super.span);
  final String name;
  final String type;
  final Expression? value;
  final bool secret;
}
