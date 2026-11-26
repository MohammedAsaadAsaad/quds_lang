import 'source.dart';

/// AST node representing a node.
sealed class Node {
  /// Creates a [Node] AST node.
  const Node(this.span);

  /// The span of this node.
  final SourceSpan span;
}

/// AST node representing a program.
class Program extends Node {
  /// Creates a [Program] AST node.
  const Program(this.statements, super.span);

  /// The statements of this node.
  final List<Statement> statements;
}

/// AST node representing a statement.
sealed class Statement extends Node {
  /// Creates a [Statement] AST node.
  const Statement(super.span);
}

/// AST node representing a function declaration.
class FunctionDeclaration extends Statement {
  /// Creates a [FunctionDeclaration] AST node.
  const FunctionDeclaration(this.name, this.parameters, this.returnType,
      this.body, this.expressionBody, super.span,
      {this.isAsync = false,
      this.annotations = const <Metadata>[],
      this.generator = '',
      this.visibility = '',
      this.isOperator = false,
      this.readonlyMethod = false,
      this.isStatic = false,
      this.conversionKind = '',
      this.conversionOwner = '',
      this.typeParameters = const [],
      this.documentation});

  /// The name of this node.
  final String name;

  /// The parameters of this node.
  final List<Parameter> parameters;

  /// The type parameters of this node.
  final List<TypeParameter> typeParameters;

  /// The return type of this node.
  final String? returnType;

  /// The body of this node.
  final List<Statement>? body;

  /// The expression body of this node.
  final Expression? expressionBody;

  /// The is async of this node.
  final bool isAsync;

  /// The annotations of this node.
  final List<Metadata> annotations;

  /// Empty, `sync`, or `async`. A non-empty value means a generator.
  final String generator;

  /// Empty, `private`, or `protected`.
  final String visibility;

  /// The is operator of this node.
  final bool isOperator;

  /// The readonly method of this node.
  final bool readonlyMethod;

  /// The is static of this node.
  final bool isStatic;

  /// The conversion kind of this node.
  final String conversionKind;

  /// The conversion owner of this node.
  final String conversionOwner;

  /// `#` or `///` lines immediately above this declaration.
  final String? documentation;
}

/// AST node representing a metadata.
class Metadata extends Node {
  /// Creates a [Metadata] AST node.
  const Metadata(this.name, this.arguments, super.span);

  /// The name of this node.
  final String name;

  /// The arguments of this node.
  final List<Argument> arguments;
}

/// Returns whether has annotation matches the given metadata list.
bool hasAnnotation(List<Metadata> notes, String name) =>
    notes.any((note) => note.name == name);

/// Classification enum for parameter kind.
enum ParameterKind { dual, requiredNamed, optionalNamed, optionalPositional }

/// AST node representing a parameter.
class Parameter extends Node {
  /// Creates a [Parameter] AST node.
  const Parameter(this.name, this.type, this.mutable, super.span,
      {this.defaultValue,
      this.variadic = false,
      this.initializing = '',
      ParameterKind? kind})
      : kind = kind ??
            (defaultValue == null
                ? ParameterKind.dual
                : ParameterKind.optionalNamed);

  /// The name of this node.
  final String name;

  /// The type of this node.
  final String type;

  /// The mutable of this node.
  final bool mutable;

  /// The default value of this node.
  final Expression? defaultValue;

  /// The kind of this node.
  final ParameterKind kind;

  /// Whether is named holds for this node.
  bool get isNamed =>
      kind == ParameterKind.requiredNamed ||
      kind == ParameterKind.optionalNamed;

  /// Whether needs adapter holds for this node.
  bool get needsAdapter => kind != ParameterKind.dual || defaultValue != null;

  /// `...name: Type` collects the remaining positional arguments as `List<Type>`.
  final bool variadic;

  /// Empty, `this`, or `super`. A non-empty value is an initializing formal.
  final String initializing;
}

/// Classification enum for binding mode.
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

/// AST node representing a binding.
class Binding extends Statement {
  /// Creates a [Binding] AST node.
  const Binding(
      this.name, this.mode, this.type, this.operator, this.value, super.span,
      {this.open = false});

  /// The name of this node.
  final String name;

  /// The mode of this node.
  final BindingMode mode;

  /// The type of this node.
  final String? type;

  /// The operator of this node.
  final String operator;

  /// The value of this node.
  final Expression value;

  /// A `late` binding that has no initializer yet.
  final bool open;
}

/// AST node representing a if statement.
class IfStatement extends Statement {
  /// Creates a [IfStatement] AST node.
  const IfStatement(this.condition, this.thenBody, this.elseBody, super.span);

  /// The condition of this node.
  final Expression condition;

  /// The else body of this node.
  final List<Statement> thenBody, elseBody;
}

/// AST node representing a for statement.
class ForStatement extends Statement {
  /// Creates a [ForStatement] AST node.
  const ForStatement(this.name, this.iterable, this.body, super.span,
      {this.awaiting = false, this.index, this.step, this.elseBody = const []});

  /// The name of this node.
  final String name;

  /// The index in `for index, name in`, or the first field of a pair.
  final String? index;

  /// The iterable of this node.
  final Expression iterable;

  /// The body of this node.
  final List<Statement> body;

  /// The awaiting of this node.
  final bool awaiting;

  /// The stride in `for name in range step value`.
  final Expression? step;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
}

/// AST node representing a return statement.
class ReturnStatement extends Statement {
  /// Creates a [ReturnStatement] AST node.
  const ReturnStatement(this.value, super.span);

  /// The value of this node.
  final Expression? value;
}

/// AST node representing a expression statement.
class ExpressionStatement extends Statement {
  /// Creates a [ExpressionStatement] AST node.
  const ExpressionStatement(this.expression, super.span);

  /// The expression of this node.
  final Expression expression;
}

/// AST node representing a expression.
sealed class Expression extends Node {
  /// Creates a [Expression] AST node.
  const Expression(super.span);
}

/// AST node representing a literal.
class Literal extends Expression {
  /// Creates a [Literal] AST node.
  const Literal(this.value, super.span);

  /// The value of this node.
  final Object? value;
}

/// AST node representing a identifier.
class Identifier extends Expression {
  /// Creates a [Identifier] AST node.
  const Identifier(this.name, super.span);

  /// The name of this node.
  final String name;
}

/// AST node representing a unary expression.
class UnaryExpression extends Expression {
  /// Creates a [UnaryExpression] AST node.
  const UnaryExpression(this.operator, this.operand, super.span);

  /// The operator of this node.
  final String operator;

  /// The operand of this node.
  final Expression operand;
}

/// AST node representing a binary expression.
class BinaryExpression extends Expression {
  /// Creates a [BinaryExpression] AST node.
  const BinaryExpression(this.left, this.operator, this.right, super.span);

  /// The right of this node.
  final Expression left, right;

  /// The operator of this node.
  final String operator;
}

/// `operand is Type`, `operand is! Type`, or `operand as Type`.
class TypeTestExpression extends Expression {
  /// Creates a [TypeTestExpression] AST node.
  const TypeTestExpression(this.operand, this.operator, this.type, super.span);

  /// The operand of this node.
  final Expression operand;

  /// The operator of this node.
  final String operator;

  /// The type of this node.
  final String type;
}

/// AST node representing a list expression.
class ListExpression extends Expression {
  /// Creates a [ListExpression] AST node.
  const ListExpression(this.elements, super.span, {this.nullAware = const []});

  /// The elements of this node.
  final List<Expression> elements;

  /// Parallel to [elements]. True omits a null element after one evaluation.
  final List<bool> nullAware;
}

/// AST node representing a argument.
class Argument extends Node {
  /// Creates a [Argument] AST node.
  const Argument(this.name, this.value, super.span);

  /// The name of this node.
  final String? name;

  /// The value of this node.
  final Expression value;
}

/// AST node representing a call expression.
class CallExpression extends Expression {
  /// Creates a [CallExpression] AST node.
  const CallExpression(this.callee, this.arguments, super.span);

  /// The callee of this node.
  final Expression callee;

  /// The arguments of this node.
  final List<Argument> arguments;
}

/// AST node representing a interpolated string.
class InterpolatedString extends Expression {
  /// Creates a [InterpolatedString] AST node.
  const InterpolatedString(this.parts, super.span);

  /// Alternating text literals and expressions, in evaluation order.
  final List<Expression> parts;
}

/// `{age=}` evaluates [value] once and shows its source text beside it.
class ShownExpression extends Expression {
  /// Creates a [ShownExpression] AST node.
  const ShownExpression(this.value, this.text, super.span);

  /// The value of this node.
  final Expression value;

  /// The text of this node.
  final String text;
}

/// AST node representing a while statement.
class WhileStatement extends Statement {
  /// Creates a [WhileStatement] AST node.
  const WhileStatement(this.condition, this.body, super.span,
      {this.letName, this.pattern, this.elseBody = const []});

  /// The condition of this node.
  final Expression condition;

  /// The body of this node.
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
  /// Creates a [GuardedStatement] AST node.
  const GuardedStatement(this.statement, this.condition, super.span,
      {this.letName, this.pattern, this.alternate});

  /// The statement of this node.
  final Statement statement;

  /// The condition of this node.
  final Expression condition;

  /// The let name of this node.
  final String? letName;

  /// The pattern of this node.
  final Pattern? pattern;

  /// The value used when the condition does not hold. It fills the same slot.
  final Expression? alternate;
}

/// A `for`, `while`, or `repeat` used as a value. `break expr` supplies it.
class LoopExpression extends Expression {
  /// Creates a [LoopExpression] AST node.
  const LoopExpression(this.loop, this.fallback, super.span);

  /// The loop of this node.
  final Statement loop;

  /// The value when the loop finishes without `break`. Null means a null result.
  final Expression? fallback;
}

/// Names bound once, left to right, before [value]. They do not escape.
class WhereExpression extends Expression {
  /// Creates a [WhereExpression] AST node.
  const WhereExpression(this.value, this.bindings, super.span,
      {this.block = false});

  /// The value of this node.
  final Expression value;

  /// The bindings of this node.
  final List<Binding> bindings;

  /// True when the bindings occupy an indented block.
  final bool block;
}

/// `a, b = b, a` or `name, age = person`. Every right-hand value runs first.
class ParallelAssignment extends Statement {
  /// Creates a [ParallelAssignment] AST node.
  const ParallelAssignment(this.targets, this.values, super.span);

  /// The targets of this node.
  final List<Pattern> targets;

  /// The values of this node.
  final List<Expression> values;
}

/// AST node representing a break statement.
class BreakStatement extends Statement {
  /// Creates a [BreakStatement] AST node.
  const BreakStatement(this.label, super.span, {this.value});

  /// The label of this node.
  final String? label;

  /// The value of `break expr` inside a loop that is itself an expression.
  final Expression? value;
}

/// AST node representing a continue statement.
class ContinueStatement extends Statement {
  /// Creates a [ContinueStatement] AST node.
  const ContinueStatement(this.label, super.span);

  /// The label of this node.
  final String? label;
}

/// AST node representing a label statement.
class LabelStatement extends Statement {
  /// Creates a [LabelStatement] AST node.
  const LabelStatement(this.name, this.statement, super.span);

  /// The name of this node.
  final String name;

  /// The statement of this node.
  final Statement statement;
}

/// AST node representing a import declaration.
class ImportDeclaration extends Statement {
  /// Creates a [ImportDeclaration] AST node.
  const ImportDeclaration(this.uri, this.prefix, super.span,
      {this.condition,
      this.export = false,
      this.deferred = false,
      this.show = const [],
      this.hide = const []});

  /// The uri of this node.
  final String uri;

  /// The prefix of this node.
  final String? prefix;

  /// `use uri as prefix deferred` loads the library through `prefix.loadLibrary`.
  final bool deferred;

  /// `use uri when condition`. The import is kept only when the condition is true.
  final Expression? condition;

  /// `export uri` re-exports the library and does not import those names here.
  final bool export;

  /// `show a, b` keeps only these names. Empty means every public name.
  final List<String> show;

  /// `hide a, b` drops these names. Ignored when [show] is not empty.
  final List<String> hide;
}

/// AST node representing a part directive.
class PartDirective extends Statement {
  /// Creates a [PartDirective] AST node.
  const PartDirective(this.uri, this.of, super.span);

  /// The uri of this node.
  final String uri;

  /// The of of this node.
  final bool of;
}

/// A library section opened by `:: graph` or `:: graph::weighted`.
///
/// An empty [path] is a bare `::`, which returns later declarations to the
/// library root. The section runs until the next header or the end of the file.
class SectionDeclaration extends Statement {
  /// Creates a [SectionDeclaration] AST node.
  const SectionDeclaration(this.path, super.span);

  /// The path of this node.
  final String path;
}

/// AST node representing a field declaration.
class FieldDeclaration extends Node {
  /// Creates a [FieldDeclaration] AST node.
  const FieldDeclaration(this.name, this.type, this.mutable, this.requiredField,
      this.initializer, super.span,
      {this.visibility = '',
      this.isStatic = false,
      this.isConst = false,
      this.isEvent = false,
      this.lazyBody,
      this.annotations = const []});

  /// The name of this node.
  final String name;

  /// The type of this node.
  final String type;

  /// The mutable of this node.
  final bool mutable;

  /// The required field of this node.
  final bool requiredField;

  /// The initializer of this node.
  final Expression? initializer;

  /// `name: Type by lazy:` computes this body on the first read.
  final List<Statement>? lazyBody;

  /// Empty, `private`, or `protected`.
  final String visibility;

  /// The is static of this node.
  final bool isStatic;

  /// The is const of this node.
  final bool isConst;

  /// `event name: Type`. Outsiders subscribe with `add`. The class uses `raise`.
  final bool isEvent;

  /// The annotations of this node.
  final List<Metadata> annotations;
}

/// AST node representing a property declaration.
class PropertyDeclaration extends Node {
  /// Creates a [PropertyDeclaration] AST node.
  const PropertyDeclaration(this.name, this.type, this.getter, this.getterBody,
      this.setter, this.setterBody, super.span,
      {this.visibility = ''});

  /// The name of this node.
  final String name;

  /// The type of this node.
  final String type;

  /// The getter of this node.
  final Expression? getter;

  /// The getter body of this node.
  final List<Statement>? getterBody;

  /// The setter of this node.
  final String? setter;

  /// The setter body of this node.
  final List<Statement>? setterBody;

  /// The visibility of this node.
  final String visibility;
}

/// AST node representing a super constructor call.
class SuperConstructorCall extends Node {
  /// Creates a [SuperConstructorCall] AST node.
  const SuperConstructorCall(this.name, this.arguments, super.span,
      {this.isRedirect = false});

  /// The name of this node.
  final String? name;

  /// The arguments of this node.
  final List<Argument> arguments;

  /// The is redirect of this node.
  final bool isRedirect;
}

/// AST node representing a constructor declaration.
class ConstructorDeclaration extends Node {
  /// Creates a [ConstructorDeclaration] AST node.
  const ConstructorDeclaration(
      this.name, this.parameters, this.body, this.expressionBody, super.span,
      {this.factory = false, this.constant = false, this.superCall});

  /// The name of this node.
  final String? name;

  /// The parameters of this node.
  final List<Parameter> parameters;

  /// The body of this node.
  final List<Statement>? body;

  /// The expression body of this node.
  final Expression? expressionBody;

  /// The factory of this node.
  final bool factory;

  /// The constant of this node.
  final bool constant;

  /// The super call of this node.
  final SuperConstructorCall? superCall;
}

/// AST node representing a class case.
class ClassCase extends Node {
  /// Creates a [ClassCase] AST node.
  const ClassCase(this.name, this.fields, super.span,
      {this.arguments = const [],
      this.constructorName,
      this.typeArguments = const []});

  /// The name of this node.
  final String name;

  /// The fields of this node.
  final List<FieldDeclaration> fields;

  /// The arguments of this node.
  final List<Argument> arguments;

  /// The constructor name of this node.
  final String? constructorName;

  /// The type arguments of this node.
  final List<String> typeArguments;
}

/// AST node representing a type parameter.
class TypeParameter extends Node {
  /// Creates a [TypeParameter] AST node.
  const TypeParameter(this.name, super.span, {this.variance = '', this.bound});

  /// The name of this node.
  final String name;

  /// Empty, `in`, or `out`.
  final String variance;

  /// The bound of this node.
  final String? bound;
}

/// AST node representing a class declaration.
class ClassDeclaration extends Statement {
  /// Creates a [ClassDeclaration] AST node.
  const ClassDeclaration(this.name, this.kind, this.fields, this.methods,
      this.cases, this.annotations, super.span,
      {this.superclass,
      this.mixins = const [],
      this.interfaces = const [],
      this.interfaceDelegates = const {},
      this.onType,
      this.modifiers = const [],
      this.requirements = const [],
      this.constructors = const [],
      this.properties = const [],
      this.typeParameters = const [],
      this.documentation,
      this.visibility = ''});

  /// The name of this node.
  final String name;

  /// `class`, `value`, `sealed`, `sealedType`, `mixin`, `mixinClass`, or `interface`.
  final String kind;

  /// The fields of this node.
  final List<FieldDeclaration> fields;

  /// The methods of this node.
  final List<FunctionDeclaration> methods;

  /// The cases of this node.
  final List<ClassCase> cases;

  /// The annotations of this node.
  final List<Metadata> annotations;

  /// The superclass of this node.
  final String? superclass;

  /// The mixins of this node.
  final List<String> mixins;

  /// The interfaces of this node.
  final List<String> interfaces;

  /// Maps an implemented interface type to the field name delegating it
  /// (`implements UserStore by inner`).
  final Map<String, String> interfaceDelegates;

  /// The on type of this node.
  final String? onType;

  /// The modifiers of this node.
  final List<String> modifiers;

  /// The requirements of this node.
  final List<Expression> requirements;

  /// The constructors of this node.
  final List<ConstructorDeclaration> constructors;

  /// The properties of this node.
  final List<PropertyDeclaration> properties;

  /// The type parameters of this node.
  final List<TypeParameter> typeParameters;

  /// `#` or `///` lines immediately above this declaration.
  final String? documentation;

  /// Empty or `internal`.
  final String visibility;
}

/// AST node representing a if let statement.
class IfLetStatement extends Statement {
  /// Creates a [IfLetStatement] AST node.
  const IfLetStatement(
      this.name, this.value, this.thenBody, this.elseBody, super.span);

  /// The name of this node.
  final String name;

  /// The value of this node.
  final Expression value;

  /// The else body of this node.
  final List<Statement> thenBody, elseBody;
}

/// AST node representing a defer statement.
class DeferStatement extends Statement {
  /// Creates a [DeferStatement] AST node.
  const DeferStatement(this.expression, super.span);

  /// The expression of this node.
  final Expression expression;
}

/// AST node representing a if case statement.
class IfCaseStatement extends Statement {
  /// Creates a [IfCaseStatement] AST node.
  const IfCaseStatement(this.scrutinee, this.pattern, this.body, super.span,
      {this.guard, this.elseBody = const []});

  /// The scrutinee of this node.
  final Expression scrutinee;

  /// The pattern of this node.
  final Pattern pattern;

  /// The guard of this node.
  final Expression? guard;

  /// The body of this node.
  final List<Statement> body;

  /// The else body of this node.
  final List<Statement> elseBody;
}

/// AST node representing a when statement.
class WhenStatement extends Statement {
  /// Creates a [WhenStatement] AST node.
  const WhenStatement(this.condition, this.body, super.span);

  /// The condition of this node.
  final Expression condition;

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a using statement.
class UsingStatement extends Statement {
  /// Creates a [UsingStatement] AST node.
  const UsingStatement(this.name, this.value, this.body, super.span,
      {this.async = false, this.scoped = false});

  /// The name of this node.
  final String name;

  /// The value of this node.
  final Expression value;

  /// The body of this node.
  final List<Statement> body;

  /// The async of this node.
  final bool async;

  /// The scoped of this node.
  final bool scoped;
}

/// AST node representing a lock statement.
class LockStatement extends Statement {
  /// Creates a [LockStatement] AST node.
  const LockStatement(this.mutex, this.body, super.span, {this.scoped = false});

  /// The mutex of this node.
  final Expression mutex;

  /// The body of this node.
  final List<Statement> body;

  /// The scoped of this node.
  final bool scoped;
}

/// AST node representing a index assignment.
class IndexAssignment extends Statement {
  /// Creates a [IndexAssignment] AST node.
  const IndexAssignment(this.target, this.operator, this.value, super.span);

  /// The target of this node.
  final IndexExpression target;

  /// The operator of this node.
  final String operator;

  /// The value of this node.
  final Expression value;
}

/// AST node representing a member assignment.
class MemberAssignment extends Statement {
  /// Creates a [MemberAssignment] AST node.
  const MemberAssignment(
      this.object, this.name, this.operator, this.value, super.span);

  /// The object of this node.
  final Expression object;

  /// The name of this node.
  final String name;

  /// The operator of this node.
  final String operator;

  /// The value of this node.
  final Expression value;
}

/// AST node representing a alias declaration.
class AliasDeclaration extends Statement {
  /// Creates a [AliasDeclaration] AST node.
  const AliasDeclaration(this.name, this.target, super.span,
      {this.documentation, this.visibility = ''});

  /// The name of this node.
  final String name;

  /// The target of this node.
  final String target;

  /// `#` or `///` lines immediately above this declaration.
  final String? documentation;

  /// Empty or `internal`.
  final String visibility;
}

/// AST node representing a require statement.
class RequireStatement extends Statement {
  /// Creates a [RequireStatement] AST node.
  const RequireStatement(this.condition, super.span,
      {this.message, this.kind = 'require', this.source});

  /// The condition of this node.
  final Expression condition;

  /// The message of this node.
  final Expression? message;

  /// `require`, `check`, or `assert`.
  final String kind;

  /// Source text of [condition], used when [message] is omitted.
  final String? source;
}

/// AST node representing a raise statement.
class RaiseStatement extends Statement {
  /// Creates a [RaiseStatement] AST node.
  const RaiseStatement(this.name, this.arguments, super.span);

  /// The name of this node.
  final String name;

  /// The arguments of this node.
  final List<Argument> arguments;
}

/// AST node representing a nameof expression.
class NameofExpression extends Expression {
  /// Creates a [NameofExpression] AST node.
  const NameofExpression(this.target, this.text, super.span);

  /// The target of this node.
  final Expression target;

  /// The path as written, such as `user.name`.
  final String text;
}

/// AST node representing a extension declaration.
class ExtensionDeclaration extends Statement {
  /// Creates a [ExtensionDeclaration] AST node.
  const ExtensionDeclaration(this.name, this.target, this.methods, super.span,
      {this.typeParameters = const [],
      this.properties = const [],
      this.visibility = ''});

  /// The name of this node.
  final String? name;

  /// The target of this node.
  final String target;

  /// The methods of this node.
  final List<FunctionDeclaration> methods;

  /// The type parameters of this node.
  final List<TypeParameter> typeParameters;

  /// The properties of this node.
  final List<PropertyDeclaration> properties;

  /// Empty or `internal`.
  final String visibility;
}

/// AST node representing a this expression.
class ThisExpression extends Expression {
  /// Creates a [ThisExpression] AST node.
  const ThisExpression(super.span);
}

/// AST node representing a watch statement.
class WatchStatement extends Statement {
  /// Creates a [WatchStatement] AST node.
  const WatchStatement(this.value, this.body, super.span);

  /// The value of this node.
  final Expression value;

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a batch statement.
class BatchStatement extends Statement {
  /// Creates a [BatchStatement] AST node.
  const BatchStatement(this.body, super.span);

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a once statement.
class OnceStatement extends Statement {
  /// Creates a [OnceStatement] AST node.
  const OnceStatement(this.body, super.span);

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a lambda.
class Lambda extends Expression {
  /// Creates a [Lambda] AST node.
  const Lambda(this.parameters, this.expressionBody, this.body, super.span);

  /// The parameters of this node.
  final List<Parameter> parameters;

  /// The expression body of this node.
  final Expression? expressionBody;

  /// The body of this node.
  final List<Statement>? body;
}

/// AST node representing a member access.
class MemberAccess extends Expression {
  /// Creates a [MemberAccess] AST node.
  const MemberAccess(this.object, this.name, this.nullAware, super.span);

  /// The object of this node.
  final Expression object;

  /// The name of this node.
  final String name;

  /// The null aware of this node.
  final bool nullAware;
}

/// AST node representing a index expression.
class IndexExpression extends Expression {
  /// Creates a [IndexExpression] AST node.
  const IndexExpression(this.object, this.index, super.span);

  /// The object of this node.
  final Expression object;

  /// The index of this node.
  final Expression index;
}

/// `text[1..]`, `text[..<n]`, and `items[1..3]`. A missing start is 0. A
/// missing end runs through the last element. [inclusive] is `..`; `..<` is
/// exclusive.
class SliceExpression extends Expression {
  /// Creates a [SliceExpression] AST node.
  const SliceExpression(
      this.object, this.start, this.end, this.inclusive, super.span);

  /// The object of this node.
  final Expression object;

  /// The start of this node.
  final Expression? start;

  /// The end of this node.
  final Expression? end;

  /// The inclusive of this node.
  final bool inclusive;
}

/// `a <= b < c`. Every operand runs once, from left to right.
class ChainComparison extends Expression {
  /// Creates a [ChainComparison] AST node.
  const ChainComparison(this.operands, this.operators, super.span);

  /// The operands of this node.
  final List<Expression> operands;

  /// The operators of this node.
  final List<String> operators;
}

/// AST node representing a map expression.
class MapExpression extends Expression {
  /// Creates a [MapExpression] AST node.
  const MapExpression(this.keys, this.values, super.span);

  /// The values of this node.
  final List<Expression> keys, values;
}

/// AST node representing a set expression.
class SetExpression extends Expression {
  /// Creates a [SetExpression] AST node.
  const SetExpression(this.elements, super.span, {this.nullAware = const []});

  /// The elements of this node.
  final List<Expression> elements;

  /// The null aware of this node.
  final List<bool> nullAware;
}

/// AST node representing a record expression.
class RecordExpression extends Expression {
  /// Creates a [RecordExpression] AST node.
  const RecordExpression(this.fields, super.span, {this.names = const []});

  /// The fields of this node.
  final List<Expression> fields;

  /// The names of this node.
  final List<String?> names;
}

/// AST node representing a range expression.
class RangeExpression extends Expression {
  /// Creates a [RangeExpression] AST node.
  const RangeExpression(this.start, this.end, this.inclusive, super.span);

  /// The end of this node.
  final Expression start, end;

  /// The inclusive of this node.
  final bool inclusive;
}

/// AST node representing a await expression.
class AwaitExpression extends Expression {
  /// Creates a [AwaitExpression] AST node.
  const AwaitExpression(this.operand, super.span);

  /// The operand of this node.
  final Expression operand;
}

/// AST node representing a propagate expression.
class PropagateExpression extends Expression {
  /// Creates a [PropagateExpression] AST node.
  const PropagateExpression(this.operand, super.span);

  /// The operand of this node.
  final Expression operand;
}

/// AST node representing a pattern.
sealed class Pattern extends Node {
  /// Creates a [Pattern] AST node.
  const Pattern(super.span);
}

/// AST node representing a wildcard pattern.
class WildcardPattern extends Pattern {
  /// Creates a [WildcardPattern] AST node.
  const WildcardPattern(super.span);
}

/// AST node representing a binding pattern.
class BindingPattern extends Pattern {
  /// Creates a [BindingPattern] AST node.
  const BindingPattern(this.name, super.span, {this.shadow = false});

  /// The name of this node.
  final String name;

  /// The shadow of this node.
  final bool shadow;
}

/// AST node representing a literal pattern.
class LiteralPattern extends Pattern {
  /// Creates a [LiteralPattern] AST node.
  const LiteralPattern(this.literal, super.span);

  /// The literal of this node.
  final Expression literal;
}

/// AST node representing a constructor pattern.
class ConstructorPattern extends Pattern {
  /// Creates a [ConstructorPattern] AST node.
  const ConstructorPattern(this.typeName, this.fields, this.names, super.span);

  /// The type name of this node.
  final String typeName;

  /// The fields of this node.
  final List<Pattern> fields;

  /// The names of this node.
  final List<String?> names;
}

/// AST node representing a list pattern.
class ListPattern extends Pattern {
  /// Creates a [ListPattern] AST node.
  const ListPattern(this.elements, super.span);

  /// The elements of this node.
  final List<Pattern> elements;
}

/// AST node representing a match arm.
class MatchArm extends Node {
  /// Creates a [MatchArm] AST node.
  const MatchArm(this.pattern, this.body, super.span, {this.guard});

  /// The pattern of this node.
  final Pattern pattern;

  /// The body of this node.
  final List<Statement> body;

  /// The guard of this node.
  final Expression? guard;
}

/// AST node representing a typed pattern.
class TypedPattern extends Pattern {
  /// Creates a [TypedPattern] AST node.
  const TypedPattern(this.type, this.name, super.span, {this.shadow = false});

  /// The type of this node.
  final String type;

  /// The name of this node.
  final String? name;

  /// The shadow of this node.
  final bool shadow;
}

/// AST node representing a do expression.
class DoExpression extends Expression {
  /// Creates a [DoExpression] AST node.
  const DoExpression(this.body, super.span);

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a result statement.
class ResultStatement extends Statement {
  /// Creates a [ResultStatement] AST node.
  const ResultStatement(this.value, super.span);

  /// The value of this node.
  final Expression value;
}

/// AST node representing a capture expression.
class CaptureExpression extends Expression {
  /// Creates a [CaptureExpression] AST node.
  const CaptureExpression(this.names, this.body, super.span);

  /// The names of this node.
  final List<String> names;

  /// The body of this node.
  final Expression body;
}

/// AST node representing a conversion expression.
class ConversionExpression extends Expression {
  /// Creates a [ConversionExpression] AST node.
  const ConversionExpression(this.operand, this.type, this.safe, super.span);

  /// The operand of this node.
  final Expression operand;

  /// The type of this node.
  final String type;

  /// The safe of this node.
  final bool safe;
}

/// AST node representing a with expression.
class WithExpression extends Expression {
  /// Creates a [WithExpression] AST node.
  const WithExpression(
      this.receiver, this.fields, this.values, this.nullAware, super.span);

  /// The receiver of this node.
  final Expression receiver;

  /// The fields of this node.
  final List<String> fields;

  /// The values of this node.
  final List<Expression> values;

  /// The null aware of this node.
  final bool nullAware;
}

/// AST node representing a dot shorthand.
class DotShorthand extends Expression {
  /// Creates a [DotShorthand] AST node.
  const DotShorthand(this.name, this.arguments, super.span);

  /// The name of this node.
  final String name;

  /// The arguments of this node.
  final List<Argument>? arguments;
}

/// AST node representing a assign expression.
class AssignExpression extends Expression {
  /// Creates a [AssignExpression] AST node.
  const AssignExpression(this.name, this.operator, this.value, super.span);

  /// The operator of this node.
  final String name, operator;

  /// The value of this node.
  final Expression value;
}

/// AST node representing a test declaration.
class TestDeclaration extends Statement {
  /// Creates a [TestDeclaration] AST node.
  const TestDeclaration(
      this.kind, this.title, this.isAsync, this.body, super.span);

  /// The title of this node.
  final String kind, title;

  /// The is async of this node.
  final bool isAsync;

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a cfor statement.
class CForStatement extends Statement {
  /// Creates a [CForStatement] AST node.
  const CForStatement(
      this.init, this.condition, this.step, this.body, super.span,
      {this.elseBody = const []});

  /// The init of this node.
  final Statement init;

  /// The condition of this node.
  final Expression condition;

  /// The step of this node.
  final Expression? step;

  /// The body of this node.
  final List<Statement> body;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
}

/// AST node representing a repeat statement.
class RepeatStatement extends Statement {
  /// Creates a [RepeatStatement] AST node.
  const RepeatStatement(this.body, this.condition, super.span,
      {this.count, this.elseBody = const []});

  /// The body of this node.
  final List<Statement> body;

  /// The condition of `repeat: ... while condition`.
  final Expression? condition;

  /// The count of `repeat count:`.
  final Expression? count;

  /// Runs only when the loop finishes without `break`.
  final List<Statement> elseBody;
}

/// AST node representing a match statement.
class MatchStatement extends Statement {
  /// Creates a [MatchStatement] AST node.
  const MatchStatement(this.value, this.arms, super.span);

  /// The value of this node.
  final Expression value;

  /// The arms of this node.
  final List<MatchArm> arms;
}

/// AST node representing a spread element.
class SpreadElement extends Expression {
  /// Creates a [SpreadElement] AST node.
  const SpreadElement(this.operand, this.nullAware, super.span);

  /// The operand of this node.
  final Expression operand;

  /// The null aware of this node.
  final bool nullAware;
}

/// AST node representing a map comprehension.
class MapComprehension extends Expression {
  /// Creates a [MapComprehension] AST node.
  const MapComprehension(this.condition, this.name, this.iterable, this.thenMap,
      this.elseMap, super.span);

  /// The condition of this node.
  final Expression? condition;

  /// The name of this node.
  final String? name;

  /// The iterable of this node.
  final Expression? iterable;

  /// The then map of this node.
  final MapExpression thenMap;

  /// The else map of this node.
  final MapExpression? elseMap;
}

/// AST node representing a if expression.
class IfExpression extends Expression {
  /// Creates a [IfExpression] AST node.
  const IfExpression(
      this.condition, this.thenValue, this.elseValue, super.span);

  /// The else value of this node.
  final Expression condition, thenValue, elseValue;
}

/// AST node representing a match expr arm.
class MatchExprArm extends Node {
  /// Creates a [MatchExprArm] AST node.
  const MatchExprArm(this.pattern, this.result, super.span, {this.guard});

  /// The pattern of this node.
  final Pattern pattern;

  /// The result of this node.
  final Expression result;

  /// The guard of this node.
  final Expression? guard;
}

/// AST node representing a match expression.
class MatchExpression extends Expression {
  /// Creates a [MatchExpression] AST node.
  const MatchExpression(this.value, this.arms, super.span);

  /// The value of this node.
  final Expression value;

  /// The arms of this node.
  final List<MatchExprArm> arms;
}

/// AST node representing a try expression.
class TryExpression extends Expression {
  /// Creates a [TryExpression] AST node.
  const TryExpression(this.operand, this.fallback, super.span);

  /// The fallback of this node.
  final Expression operand, fallback;
}

/// AST node representing a try statement.
class TryStatement extends Statement {
  /// Creates a [TryStatement] AST node.
  const TryStatement(this.body, this.catches, this.finallyBody, super.span,
      {this.elseBody = const []});

  /// The else body of this node.
  final List<Statement> body, finallyBody, elseBody;

  /// The catches of this node.
  final List<CatchClause> catches;
}

/// AST node representing a catch clause.
class CatchClause extends Node {
  /// Creates a [CatchClause] AST node.
  const CatchClause(this.name, this.type, this.trace, this.body, super.span);

  /// The name of this node.
  final String name;

  /// The trace of this node.
  final String? type, trace;

  /// The body of this node.
  final List<Statement> body;
}

/// AST node representing a throw statement.
class ThrowStatement extends Statement {
  /// Creates a [ThrowStatement] AST node.
  const ThrowStatement(this.value, super.span);

  /// The value of this node.
  final Expression value;
}

/// AST node representing a rethrow statement.
class RethrowStatement extends Statement {
  /// Creates a [RethrowStatement] AST node.
  const RethrowStatement(super.span);
}

/// AST node representing a yield statement.
class YieldStatement extends Statement {
  /// Creates a [YieldStatement] AST node.
  const YieldStatement(this.value, this.star, super.span);

  /// The value of this node.
  final Expression value;

  /// The star of this node.
  final bool star;
}

/// AST node representing a destructure statement.
class DestructureStatement extends Statement {
  /// Creates a [DestructureStatement] AST node.
  const DestructureStatement(this.pattern, this.value, super.span,
      {this.elseBody, this.mutable = false});

  /// The pattern of this node.
  final Pattern pattern;

  /// The value of this node.
  final Expression value;

  /// The else body of this node.
  final List<Statement>? elseBody;

  /// The mutable of this node.
  final bool mutable;
}

/// AST node representing a guard statement.
class GuardStatement extends Statement {
  /// Creates a [GuardStatement] AST node.
  const GuardStatement(this.condition, this.elseBody, super.span);

  /// The condition of this node.
  final Expression condition;

  /// The else body of this node.
  final List<Statement> elseBody;
}

/// AST node representing a duration literal.
class DurationLiteral extends Expression {
  /// Creates a [DurationLiteral] AST node.
  const DurationLiteral(this.microseconds, this.raw, super.span);

  /// The microseconds of this node.
  final int microseconds;

  /// The raw of this node.
  final String raw;
}

/// AST node representing a retry expression.
class RetryExpression extends Expression {
  /// Creates a [RetryExpression] AST node.
  const RetryExpression(
    this.attempts,
    this.bodyExpr,
    this.bodyStmts,
    super.span, {
    this.delay,
    this.backoff,
    this.whenErrorName,
    this.whenCondition,
    this.block = false,
  });

  /// The attempts of this node.
  final Expression attempts;

  /// The delay of this node.
  final Expression? delay;

  /// The backoff of this node.
  final Expression? backoff;

  /// The when error name of this node.
  final String? whenErrorName;

  /// The when condition of this node.
  final Expression? whenCondition;

  /// The body expr of this node.
  final Expression? bodyExpr;

  /// The body stmts of this node.
  final List<Statement>? bodyStmts;

  /// The block of this node.
  final bool block;
}

/// AST node representing a timeout expression.
class TimeoutExpression extends Expression {
  /// Creates a [TimeoutExpression] AST node.
  const TimeoutExpression(
    this.duration,
    this.bodyExpr,
    this.bodyStmts,
    super.span, {
    this.fallbackExpr,
    this.fallbackStmts,
    this.block = false,
  });

  /// The duration of this node.
  final Expression duration;

  /// The body expr of this node.
  final Expression? bodyExpr;

  /// The body stmts of this node.
  final List<Statement>? bodyStmts;

  /// The fallback expr of this node.
  final Expression? fallbackExpr;

  /// The fallback stmts of this node.
  final List<Statement>? fallbackStmts;

  /// The block of this node.
  final bool block;
}

/// AST node representing a null aware element.
class NullAwareElement extends Expression {
  /// Creates a [NullAwareElement] AST node.
  const NullAwareElement(this.value, super.span);

  /// The value of this node.
  final Expression value;
}

/// AST node representing a collection if.
class CollectionIf extends Expression {
  /// Creates a [CollectionIf] AST node.
  const CollectionIf(
      this.condition, this.thenElements, this.elseElements, super.span,
      {this.pattern, this.guard});

  /// The condition of this node.
  final Expression condition;

  /// The pattern of this node.
  final Pattern? pattern;

  /// The guard of this node.
  final Expression? guard;

  /// The then elements of this node.
  final List<Expression> thenElements;

  /// The else elements of this node.
  final List<Expression> elseElements;
}

/// AST node representing a collection for.
class CollectionFor extends Expression {
  /// Creates a [CollectionFor] AST node.
  const CollectionFor(this.name, this.iterable, this.body, super.span,
      {this.filter, this.index});

  /// The name of this node.
  final String name;

  /// The index in `for index, name in`, or the first field of a pair.
  final String? index;

  /// The iterable of this node.
  final Expression iterable;

  /// The body of this node.
  final List<Expression> body;

  /// The filter of this node.
  final Expression? filter;
}

/// AST node representing a map pattern.
class MapPattern extends Pattern {
  /// Creates a [MapPattern] AST node.
  const MapPattern(this.keys, this.values, super.span);

  /// The keys of this node.
  final List<Expression> keys;

  /// The values of this node.
  final List<Pattern> values;
}

/// AST node representing a rest pattern.
class RestPattern extends Pattern {
  /// Creates a [RestPattern] AST node.
  const RestPattern(this.name, super.span, {this.shadow = false});

  /// The name of this node.
  final String? name;

  /// The shadow of this node.
  final bool shadow;
}

/// AST node representing a or pattern.
class OrPattern extends Pattern {
  /// Creates a [OrPattern] AST node.
  const OrPattern(this.left, this.right, super.span);

  /// The right of this node.
  final Pattern left, right;
}

/// AST node representing a and pattern.
class AndPattern extends Pattern {
  /// Creates a [AndPattern] AST node.
  const AndPattern(this.left, this.right, super.span);

  /// The right of this node.
  final Pattern left, right;
}

/// AST node representing a relational pattern.
class RelationalPattern extends Pattern {
  /// Creates a [RelationalPattern] AST node.
  const RelationalPattern(this.operator, this.value, super.span);

  /// The operator of this node.
  final String operator;

  /// The value of this node.
  final Expression value;
}

/// AST node representing a cast pattern.
class CastPattern extends Pattern {
  /// Creates a [CastPattern] AST node.
  const CastPattern(this.inner, this.type, super.span);

  /// The inner of this node.
  final Pattern inner;

  /// The type of this node.
  final String type;
}

/// AST node representing a null check pattern.
class NullCheckPattern extends Pattern {
  /// Creates a [NullCheckPattern] AST node.
  const NullCheckPattern(this.inner, super.span);

  /// The inner of this node.
  final Pattern inner;
}

/// AST node representing a null assert pattern.
class NullAssertPattern extends Pattern {
  /// Creates a [NullAssertPattern] AST node.
  const NullAssertPattern(this.inner, super.span);

  /// The inner of this node.
  final Pattern inner;
}

/// AST node representing a type application.
class TypeApplication extends Expression {
  /// Creates a [TypeApplication] AST node.
  const TypeApplication(this.callee, this.arguments, super.span);

  /// The callee of this node.
  final Expression callee;

  /// The arguments of this node.
  final List<String> arguments;
}

/// AST node representing a await all expression.
class AwaitAllExpression extends Expression {
  /// Creates a [AwaitAllExpression] AST node.
  const AwaitAllExpression(this.arms, super.span);

  /// The arms of this node.
  final List<Expression> arms;
}

/// AST node representing a await isolate expression.
class AwaitIsolateExpression extends Expression {
  /// Creates a [AwaitIsolateExpression] AST node.
  const AwaitIsolateExpression(this.call, super.span);

  /// The call of this node.
  final Expression call;
}

/// AST node representing a symbol expression.
class SymbolExpression extends Expression {
  /// Creates a [SymbolExpression] AST node.
  const SymbolExpression(this.text, super.span);

  /// The text of this node.
  final String text;
}

/// AST node representing a task group statement.
class TaskGroupStatement extends Statement {
  /// Creates a [TaskGroupStatement] AST node.
  const TaskGroupStatement(this.children, super.span);

  /// Each child is a spawned expression or a nested task group, in source order.
  final List<Node> children;
}

/// AST node representing a annotation declaration.
class AnnotationDeclaration extends Statement {
  /// Creates a [AnnotationDeclaration] AST node.
  const AnnotationDeclaration(this.name, this.parameters, super.span);

  /// The name of this node.
  final String name;

  /// The parameters of this node.
  final List<Parameter> parameters;
}

/// AST node representing a config declaration.
class ConfigDeclaration extends Statement {
  /// Creates a [ConfigDeclaration] AST node.
  const ConfigDeclaration(
      this.name, this.type, this.value, this.secret, super.span);

  /// The name of this node.
  final String name;

  /// The type of this node.
  final String type;

  /// The value of this node.
  final Expression? value;

  /// The secret of this node.
  final bool secret;
}
