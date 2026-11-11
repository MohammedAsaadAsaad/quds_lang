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
      this.body, this.expressionBody, super.span);
  final String name;
  final List<Parameter> parameters;
  final String? returnType;
  final List<Statement>? body;
  final Expression? expressionBody;
}

class Parameter extends Node {
  const Parameter(this.name, this.type, this.mutable, super.span);
  final String name;
  final String type;
  final bool mutable;
}

enum BindingMode { inferred, mutable, constant, shadow }

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
