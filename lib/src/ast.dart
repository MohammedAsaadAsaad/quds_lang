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
      {this.isAsync = false, this.annotations = const []});
  final String name;
  final List<Parameter> parameters;
  final String? returnType;
  final List<Statement>? body;
  final Expression? expressionBody;
  final bool isAsync;
  final List<String> annotations;
}

class Parameter extends Node {
  const Parameter(this.name, this.type, this.mutable, super.span,
      {this.defaultValue});
  final String name;
  final String type;
  final bool mutable;
  final Expression? defaultValue;
}

enum BindingMode { inferred, mutable, constant, shadow, shadowMutable }

class Binding extends Statement {
  const Binding(
      this.name, this.mode, this.type, this.operator, this.value, super.span);
  final String name;
  final BindingMode mode;
  final String? type;
  final String operator;
  final Expression value;
}

class IfStatement extends Statement {
  const IfStatement(this.condition, this.thenBody, this.elseBody, super.span);
  final Expression condition;
  final List<Statement> thenBody, elseBody;
}

class ForStatement extends Statement {
  const ForStatement(this.name, this.iterable, this.body, super.span);
  final String name;
  final Expression iterable;
  final List<Statement> body;
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
  const ListExpression(this.elements, super.span);
  final List<Expression> elements;
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
  const ImportDeclaration(this.uri, this.prefix, super.span);
  final String uri;
  final String? prefix;
}

class FieldDeclaration extends Node {
  const FieldDeclaration(this.name, this.type, this.mutable, this.requiredField,
      this.initializer, super.span);
  final String name;
  final String type;
  final bool mutable;
  final bool requiredField;
  final Expression? initializer;
}

class ClassCase extends Node {
  const ClassCase(this.name, this.fields, super.span);
  final String name;
  final List<FieldDeclaration> fields;
}

class ClassDeclaration extends Statement {
  const ClassDeclaration(this.name, this.kind, this.fields, this.methods,
      this.cases, this.annotations, super.span);
  final String name;

  /// `class`, `value`, `sealed`, or `sealedType`.
  final String kind;
  final List<FieldDeclaration> fields;
  final List<FunctionDeclaration> methods;
  final List<ClassCase> cases;
  final List<String> annotations;
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
  const SetExpression(this.elements, super.span);
  final List<Expression> elements;
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
  const MatchArm(this.pattern, this.body, super.span);
  final Pattern pattern;
  final List<Statement> body;
}

class MatchStatement extends Statement {
  const MatchStatement(this.value, this.arms, super.span);
  final Expression value;
  final List<MatchArm> arms;
}

class DestructureStatement extends Statement {
  const DestructureStatement(this.pattern, this.value, super.span);
  final Pattern pattern;
  final Expression value;
}
