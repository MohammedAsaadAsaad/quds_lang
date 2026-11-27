/// Pure-Dart stack-based Bytecode Compiler & Virtual Machine (`QudsBytecodeVm`)
/// for accelerating compute-heavy Quds loops, recursion, numerical methods,
/// DSP, and algorithmic workloads.
///
/// Compiles hot pure-Quds programs into flat `Int32List`-style opcodes with
/// slot-indexed locals/globals (zero hash-map lookups in tight loops),
/// source-line tables, and strict `maxSteps`/`maxCallDepth`/`timeout` budgets.
/// When a script uses dynamic constructs not yet lowered to bytecode (e.g.
/// classes, `quds:viz`, async, host modules), [QudsBytecodeCompiler.tryCompile]
/// returns `null` cleanly so [QudsSession] falls back transparently to the full
/// AST evaluator.
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies).
library;

import 'dart:math' as math;

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'exceptions.dart';
import 'values.dart';

/// Compact bytecode instruction opcodes for [QudsBytecodeVm].
abstract final class QudsOp {
  static const int pushConst = 0; // operand = constIdx
  static const int pop = 1;
  static const int dup = 2;
  static const int loadLocal = 3; // operand = local slot
  static const int storeLocal = 4; // operand = local slot
  static const int loadGlobal = 5; // operand = global slot
  static const int storeGlobal = 6; // operand = global slot
  static const int add = 7;
  static const int sub = 8;
  static const int mul = 9;
  static const int div = 10;
  static const int idiv = 11;
  static const int mod = 12;
  static const int neg = 13;
  static const int eq = 14;
  static const int neq = 15;
  static const int lt = 16;
  static const int lte = 17;
  static const int gt = 18;
  static const int gte = 19;
  static const int not = 20;
  static const int jump = 21; // operand = target ip
  static const int jumpIfFalse = 22; // operand = target ip
  static const int jumpIfTrue = 23; // operand = target ip
  static const int callFn = 24; // operand = fnIdx
  static const int ret = 25;
  static const int printTop = 26;
  static const int buildList = 27; // operand = count
  static const int indexGet = 28;
  static const int indexSet = 29;
  static const int listLen = 30;
  static const int listAdd = 31;
  static const int concatStr = 32; // operand = count
  static const int callIntrinsic = 33; // operand = intrinsicId
  static const int toFixed = 34; // pops digits, pops num
  static const int halt = 35;

  static const List<String> names = [
    'PUSH_CONST',
    'POP',
    'DUP',
    'LOAD_LOCAL',
    'STORE_LOCAL',
    'LOAD_GLOBAL',
    'STORE_GLOBAL',
    'ADD',
    'SUB',
    'MUL',
    'DIV',
    'IDIV',
    'MOD',
    'NEG',
    'EQ',
    'NEQ',
    'LT',
    'LTE',
    'GT',
    'GTE',
    'NOT',
    'JUMP',
    'JUMP_IF_FALSE',
    'JUMP_IF_TRUE',
    'CALL_FN',
    'RET',
    'PRINT',
    'BUILD_LIST',
    'INDEX_GET',
    'INDEX_SET',
    'LIST_LEN',
    'LIST_ADD',
    'CONCAT_STR',
    'CALL_INTRINSIC',
    'TO_FIXED',
    'HALT',
  ];
}

abstract final class _Intrinsic {
  static const int sin = 0;
  static const int cos = 1;
  static const int tan = 2;
  static const int sqrt = 3;
  static const int abs = 4;
  static const int exp = 5;
  static const int log = 6;
  static const int floor = 7;
  static const int ceil = 8;
  static const int round = 9;
  static const int pow = 10;
  static const int min = 11;
  static const int max = 12;
  static const int toDouble = 13;
  static const int toInt = 14;
}

/// Compiled bytecode chunk for one function (or top-level `<main>`).
class QudsBytecodeFunction {
  const QudsBytecodeFunction({
    required this.name,
    required this.arity,
    required this.localCount,
    required this.ops,
    required this.operands,
    required this.lines,
    required this.constants,
  });

  final String name;
  final int arity;
  final int localCount;
  final List<int> ops;
  final List<int> operands;
  final List<int> lines;
  final List<Object?> constants;

  /// Human-readable disassembly of this function's bytecode.
  String disassemble() {
    final buf = StringBuffer()
      ..writeln('== fn $name/$arity (locals: $localCount) ==');
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final arg = operands[i];
      final opName = op < QudsOp.names.length ? QudsOp.names[op] : 'OP_$op';
      final suffix = op == QudsOp.pushConst
          ? ' #$arg (${constants[arg]})'
          : (arg != 0 ? ' $arg' : '');
      buf.writeln(
          '${i.toString().padLeft(4, '0')}  L${lines[i].toString().padLeft(3)}  $opName$suffix');
    }
    return buf.toString();
  }
}

/// Compiled bytecode module containing `<main>` and all lowered functions.
class QudsBytecodeProgram {
  const QudsBytecodeProgram({
    required this.functions,
    required this.mainIndex,
    required this.globalNames,
    required this.file,
  });

  final List<QudsBytecodeFunction> functions;
  final int mainIndex;
  final List<String> globalNames;
  final String file;

  /// Full disassembly of every function in this bytecode module.
  String disassemble() =>
      [for (final f in functions) f.disassemble()].join('\n');
}

/// Result returned by executing a [QudsBytecodeProgram] on [QudsBytecodeVm].
class QudsBytecodeRunResult {
  const QudsBytecodeRunResult({
    required this.succeeded,
    this.value,
    this.printedLines = const [],
    this.stepsExecuted = 0,
    this.elapsed = Duration.zero,
    this.globals = const {},
    this.error,
  });

  final bool succeeded;
  final Object? value;
  final List<String> printedLines;
  final int stepsExecuted;
  final Duration elapsed;
  final Map<String, Object?> globals;
  final Object? error;

  String get stdout => printedLines.join('\n');
}

class _UnsupportedBytecode implements Exception {
  const _UnsupportedBytecode();
}

/// Compiles a pure-Quds [Program] AST into a flat [QudsBytecodeProgram].
class QudsBytecodeCompiler {
  QudsBytecodeCompiler._(this._file);

  final String _file;
  final List<String> _globalNames = [];
  final Map<String, int> _globalSlots = {};
  final Map<String, int> _fnIndices = {};
  final Map<String, int> _fnArities = {};
  final Set<String> _mathPrefixes = {};

  /// Attempts to compile [program] to bytecode; returns `null` if any
  /// unsupported construct is present so the caller can fall back to AST eval.
  static QudsBytecodeProgram? tryCompile(
    Program program, {
    String file = '<bytecode>',
  }) {
    final compiler = QudsBytecodeCompiler._(file);
    try {
      return compiler._compileProgram(program);
    } on _UnsupportedBytecode {
      return null;
    }
  }

  /// Parses [source] and attempts bytecode compilation.
  static QudsBytecodeProgram? tryCompileSource(
    String source, {
    String file = '<bytecode>',
  }) {
    final tokens = const Lexer().tokenize(source, file: file);
    final program = Parser(tokens).parse();
    return tryCompile(program, file: file);
  }

  int _globalSlot(String name) => _globalSlots.putIfAbsent(name, () {
        final idx = _globalNames.length;
        _globalNames.add(name);
        return idx;
      });

  QudsBytecodeProgram _compileProgram(Program program) {
    final fnDecls = <FunctionDeclaration>[];
    final topStmts = <Statement>[];

    // Check imports & collect top-level functions (reject duplicates / overloads for VM)
    for (final stmt in program.statements) {
      if (stmt is ImportDeclaration) {
        if (stmt.uri == 'dart:math' || stmt.uri == 'quds:math') {
          if (stmt.prefix != null) _mathPrefixes.add(stmt.prefix!);
        } else {
          throw const _UnsupportedBytecode();
        }
      } else if (stmt is FunctionDeclaration) {
        if (stmt.isAsync ||
            _fnIndices.containsKey(stmt.name) ||
            stmt.parameters.any(
                (p) => p.isNamed || p.variadic || p.defaultValue != null)) {
          throw const _UnsupportedBytecode();
        }
        _fnIndices[stmt.name] = fnDecls.length;
        _fnArities[stmt.name] = stmt.parameters.length;
        fnDecls.add(stmt);
      } else {
        topStmts.add(stmt);
      }
    }

    final compiledFns = <QudsBytecodeFunction>[];
    for (final decl in fnDecls) {
      compiledFns.add(_compileFunction(decl));
    }

    // Compile top-level `<main>`
    final mainIdx = compiledFns.length;
    final mainBuilder = _FnBuilder(this, '<main>', isMain: true);
    var hasLastExpr = false;
    for (var i = 0; i < topStmts.length; i++) {
      final stmt = topStmts[i];
      final isLast = i == topStmts.length - 1;
      if (isLast && stmt is ExpressionStatement) {
        mainBuilder.compileExpr(stmt.expression);
        hasLastExpr = true;
      } else {
        mainBuilder.compileStmt(stmt);
      }
    }
    if (!hasLastExpr) {
      mainBuilder.emitConst(null, 1);
    }
    mainBuilder.emit(QudsOp.halt, 0, 1);
    compiledFns.add(mainBuilder.build());

    return QudsBytecodeProgram(
      functions: compiledFns,
      mainIndex: mainIdx,
      globalNames: List.unmodifiable(_globalNames),
      file: _file,
    );
  }

  QudsBytecodeFunction _compileFunction(FunctionDeclaration decl) {
    final fb = _FnBuilder(this, decl.name, isMain: false);
    for (final p in decl.parameters) {
      fb.declareLocal(p.name);
    }
    if (decl.expressionBody != null) {
      fb.compileExpr(decl.expressionBody!);
      fb.emit(QudsOp.ret, 0, decl.span.line);
    } else if (decl.body != null) {
      for (final s in decl.body!) {
        fb.compileStmt(s);
      }
      fb.emitConst(null, decl.span.line);
      fb.emit(QudsOp.ret, 0, decl.span.line);
    } else {
      throw const _UnsupportedBytecode();
    }
    return fb.build(arity: decl.parameters.length);
  }
}

class _LoopPatch {
  final List<int> breaks = [];
  final List<int> continues = [];
}

class _FnBuilder {
  _FnBuilder(this.compiler, this.name, {required this.isMain});

  final QudsBytecodeCompiler compiler;
  final String name;
  final bool isMain;

  final List<int> ops = [];
  final List<int> operands = [];
  final List<int> lines = [];
  final List<Object?> constants = [];
  final Map<String, int> locals = {};
  int localCount = 0;
  final List<_LoopPatch> loopStack = [];

  int declareLocal(String name) => locals.putIfAbsent(name, () => localCount++);

  int addConst(Object? v) {
    for (var i = 0; i < constants.length; i++) {
      if (constants[i] == v && constants[i].runtimeType == v.runtimeType) {
        return i;
      }
    }
    constants.add(v);
    return constants.length - 1;
  }

  int emit(int op, int arg, int line) {
    ops.add(op);
    operands.add(arg);
    lines.add(line);
    return ops.length - 1;
  }

  void emitConst(Object? v, int line) =>
      emit(QudsOp.pushConst, addConst(v), line);

  void patch(int idx, int target) => operands[idx] = target;

  QudsBytecodeFunction build({int arity = 0}) => QudsBytecodeFunction(
        name: name,
        arity: arity,
        localCount: localCount,
        ops: ops,
        operands: operands,
        lines: lines,
        constants: constants,
      );

  void compileStmt(Statement stmt) {
    final line = stmt.span.line;
    if (stmt is ExpressionStatement) {
      compileExpr(stmt.expression);
      emit(QudsOp.pop, 0, line);
      return;
    }
    if (stmt is Binding) {
      if (stmt.mode == BindingMode.lateFinal ||
          stmt.mode == BindingMode.lateMutable) {
        throw const _UnsupportedBytecode();
      }
      final isLocal = !isMain;
      final slot =
          isLocal ? declareLocal(stmt.name) : compiler._globalSlot(stmt.name);
      if (stmt.operator == '=') {
        compileExpr(stmt.value);
      } else {
        emit(isLocal ? QudsOp.loadLocal : QudsOp.loadGlobal, slot, line);
        compileExpr(stmt.value);
        switch (stmt.operator) {
          case '+=':
            emit(QudsOp.add, 0, line);
          case '-=':
            emit(QudsOp.sub, 0, line);
          case '*=':
            emit(QudsOp.mul, 0, line);
          case '/=':
            emit(QudsOp.div, 0, line);
          default:
            throw const _UnsupportedBytecode();
        }
      }
      emit(isLocal ? QudsOp.storeLocal : QudsOp.storeGlobal, slot, line);
      return;
    }
    if (stmt is IndexAssignment) {
      if (stmt.operator != '=') throw const _UnsupportedBytecode();
      compileExpr(stmt.target.object);
      compileExpr(stmt.target.index);
      compileExpr(stmt.value);
      emit(QudsOp.indexSet, 0, line);
      return;
    }
    if (stmt is ReturnStatement) {
      if (stmt.value != null) {
        compileExpr(stmt.value!);
      } else {
        emitConst(null, line);
      }
      emit(QudsOp.ret, 0, line);
      return;
    }
    if (stmt is IfStatement) {
      compileExpr(stmt.condition);
      final jFalse = emit(QudsOp.jumpIfFalse, 0, line);
      for (final s in stmt.thenBody) {
        compileStmt(s);
      }
      if (stmt.elseBody.isNotEmpty) {
        final jEnd = emit(QudsOp.jump, 0, line);
        patch(jFalse, ops.length);
        for (final s in stmt.elseBody) {
          compileStmt(s);
        }
        patch(jEnd, ops.length);
      } else {
        patch(jFalse, ops.length);
      }
      return;
    }
    if (stmt is WhileStatement) {
      if (stmt.elseBody.isNotEmpty) throw const _UnsupportedBytecode();
      final loopStart = ops.length;
      final patcher = _LoopPatch();
      loopStack.add(patcher);
      compileExpr(stmt.condition);
      final jOut = emit(QudsOp.jumpIfFalse, 0, line);
      for (final s in stmt.body) {
        compileStmt(s);
      }
      for (final c in patcher.continues) {
        patch(c, loopStart);
      }
      emit(QudsOp.jump, loopStart, line);
      final afterLoop = ops.length;
      patch(jOut, afterLoop);
      for (final b in patcher.breaks) {
        patch(b, afterLoop);
      }
      loopStack.removeLast();
      return;
    }
    if (stmt is ForStatement) {
      if (stmt.awaiting ||
          stmt.index != null ||
          stmt.elseBody.isNotEmpty ||
          stmt.iterable is! RangeExpression) {
        throw const _UnsupportedBytecode();
      }
      final range = stmt.iterable as RangeExpression;
      final iterSlot =
          isMain ? compiler._globalSlot(stmt.name) : declareLocal(stmt.name);
      final endSlot = declareLocal('__for_end_${ops.length}');
      final stepSlot = declareLocal('__for_step_${ops.length}');

      compileExpr(range.start);
      emit(isMain ? QudsOp.storeGlobal : QudsOp.storeLocal, iterSlot, line);
      compileExpr(range.end);
      emit(QudsOp.storeLocal, endSlot, line);
      if (stmt.step != null) {
        compileExpr(stmt.step!);
      } else {
        emitConst(1, line);
      }
      emit(QudsOp.storeLocal, stepSlot, line);

      final loopStart = ops.length;
      final patcher = _LoopPatch();
      loopStack.add(patcher);

      emit(isMain ? QudsOp.loadGlobal : QudsOp.loadLocal, iterSlot, line);
      emit(QudsOp.loadLocal, endSlot, line);
      emit(range.inclusive ? QudsOp.lte : QudsOp.lt, 0, line);
      final jOut = emit(QudsOp.jumpIfFalse, 0, line);

      for (final s in stmt.body) {
        compileStmt(s);
      }

      final contTarget = ops.length;
      for (final c in patcher.continues) {
        patch(c, contTarget);
      }
      emit(isMain ? QudsOp.loadGlobal : QudsOp.loadLocal, iterSlot, line);
      emit(QudsOp.loadLocal, stepSlot, line);
      emit(QudsOp.add, 0, line);
      emit(isMain ? QudsOp.storeGlobal : QudsOp.storeLocal, iterSlot, line);
      emit(QudsOp.jump, loopStart, line);

      final afterLoop = ops.length;
      patch(jOut, afterLoop);
      for (final b in patcher.breaks) {
        patch(b, afterLoop);
      }
      loopStack.removeLast();
      return;
    }
    if (stmt is RepeatStatement) {
      if (stmt.count == null ||
          stmt.condition != null ||
          stmt.elseBody.isNotEmpty) {
        throw const _UnsupportedBytecode();
      }
      final counterSlot = declareLocal('__rep_${ops.length}');
      compileExpr(stmt.count!);
      emit(QudsOp.storeLocal, counterSlot, line);

      final loopStart = ops.length;
      final patcher = _LoopPatch();
      loopStack.add(patcher);

      emit(QudsOp.loadLocal, counterSlot, line);
      emitConst(0, line);
      emit(QudsOp.gt, 0, line);
      final jOut = emit(QudsOp.jumpIfFalse, 0, line);

      for (final s in stmt.body) {
        compileStmt(s);
      }

      final contTarget = ops.length;
      for (final c in patcher.continues) {
        patch(c, contTarget);
      }
      emit(QudsOp.loadLocal, counterSlot, line);
      emitConst(1, line);
      emit(QudsOp.sub, 0, line);
      emit(QudsOp.storeLocal, counterSlot, line);
      emit(QudsOp.jump, loopStart, line);

      final afterLoop = ops.length;
      patch(jOut, afterLoop);
      for (final b in patcher.breaks) {
        patch(b, afterLoop);
      }
      loopStack.removeLast();
      return;
    }
    if (stmt is BreakStatement && stmt.label == null && loopStack.isNotEmpty) {
      loopStack.last.breaks.add(emit(QudsOp.jump, 0, line));
      return;
    }
    if (stmt is ContinueStatement &&
        stmt.label == null &&
        loopStack.isNotEmpty) {
      loopStack.last.continues.add(emit(QudsOp.jump, 0, line));
      return;
    }
    throw const _UnsupportedBytecode();
  }

  void compileExpr(Expression expr) {
    final line = expr.span.line;
    if (expr is Literal) {
      emitConst(expr.value, line);
      return;
    }
    if (expr is Identifier) {
      if (expr.name == 'pi') {
        emitConst(math.pi, line);
        return;
      }
      if (expr.name == 'e') {
        emitConst(math.e, line);
        return;
      }
      if (!isMain && locals.containsKey(expr.name)) {
        emit(QudsOp.loadLocal, locals[expr.name]!, line);
        return;
      }
      if (compiler._globalSlots.containsKey(expr.name)) {
        emit(QudsOp.loadGlobal, compiler._globalSlots[expr.name]!, line);
        return;
      }
      throw const _UnsupportedBytecode();
    }
    if (expr is UnaryExpression) {
      compileExpr(expr.operand);
      if (expr.operator == '-') {
        emit(QudsOp.neg, 0, line);
        return;
      }
      if (expr.operator == 'not' || expr.operator == '!') {
        emit(QudsOp.not, 0, line);
        return;
      }
      throw const _UnsupportedBytecode();
    }
    if (expr is BinaryExpression) {
      if (expr.operator == 'and') {
        compileExpr(expr.left);
        emit(QudsOp.dup, 0, line);
        final jEnd = emit(QudsOp.jumpIfFalse, 0, line);
        emit(QudsOp.pop, 0, line);
        compileExpr(expr.right);
        patch(jEnd, ops.length);
        return;
      }
      if (expr.operator == 'or') {
        compileExpr(expr.left);
        emit(QudsOp.dup, 0, line);
        final jEnd = emit(QudsOp.jumpIfTrue, 0, line);
        emit(QudsOp.pop, 0, line);
        compileExpr(expr.right);
        patch(jEnd, ops.length);
        return;
      }
      compileExpr(expr.left);
      compileExpr(expr.right);
      switch (expr.operator) {
        case '+':
          emit(QudsOp.add, 0, line);
        case '-':
          emit(QudsOp.sub, 0, line);
        case '*':
          emit(QudsOp.mul, 0, line);
        case '/':
          emit(QudsOp.div, 0, line);
        case '~/':
          emit(QudsOp.idiv, 0, line);
        case '%':
          emit(QudsOp.mod, 0, line);
        case '==':
          emit(QudsOp.eq, 0, line);
        case '!=':
          emit(QudsOp.neq, 0, line);
        case '<':
          emit(QudsOp.lt, 0, line);
        case '<=':
          emit(QudsOp.lte, 0, line);
        case '>':
          emit(QudsOp.gt, 0, line);
        case '>=':
          emit(QudsOp.gte, 0, line);
        default:
          throw const _UnsupportedBytecode();
      }
      return;
    }
    if (expr is ListExpression) {
      for (final item in expr.elements) {
        compileExpr(item);
      }
      emit(QudsOp.buildList, expr.elements.length, line);
      return;
    }
    if (expr is IndexExpression) {
      compileExpr(expr.object);
      compileExpr(expr.index);
      emit(QudsOp.indexGet, 0, line);
      return;
    }
    if (expr is InterpolatedString) {
      for (final p in expr.parts) {
        compileExpr(p);
      }
      emit(QudsOp.concatStr, expr.parts.length, line);
      return;
    }
    if (expr is MemberAccess) {
      if (expr.object is Identifier) {
        final objName = (expr.object as Identifier).name;
        if (compiler._mathPrefixes.contains(objName)) {
          if (expr.name == 'pi') {
            emitConst(math.pi, line);
            return;
          }
          if (expr.name == 'e') {
            emitConst(math.e, line);
            return;
          }
        }
      }
      if (expr.name == 'length') {
        compileExpr(expr.object);
        emit(QudsOp.listLen, 0, line);
        return;
      }
      throw const _UnsupportedBytecode();
    }
    if (expr is CallExpression) {
      if (expr.arguments.any((a) => a.name != null)) {
        throw const _UnsupportedBytecode();
      }
      if (expr.callee is Identifier) {
        final name = (expr.callee as Identifier).name;
        if (name == 'print' && expr.arguments.length == 1) {
          compileExpr(expr.arguments.first.value);
          emit(QudsOp.printTop, 0, line);
          emitConst(null, line);
          return;
        }
        final intr = _matchIntrinsic(name, expr.arguments.length);
        if (intr != null) {
          for (final a in expr.arguments) {
            compileExpr(a.value);
          }
          emit(QudsOp.callIntrinsic, intr, line);
          return;
        }
        final fnIdx = compiler._fnIndices[name];
        if (fnIdx != null &&
            compiler._fnArities[name] == expr.arguments.length) {
          for (final a in expr.arguments) {
            compileExpr(a.value);
          }
          emit(QudsOp.callFn, fnIdx, line);
          return;
        }
      }
      if (expr.callee is MemberAccess) {
        final ma = expr.callee as MemberAccess;
        if (ma.object is Identifier &&
            compiler._mathPrefixes.contains((ma.object as Identifier).name)) {
          final intr = _matchIntrinsic(ma.name, expr.arguments.length);
          if (intr != null) {
            for (final a in expr.arguments) {
              compileExpr(a.value);
            }
            emit(QudsOp.callIntrinsic, intr, line);
            return;
          }
        }
        if (ma.name == 'add' && expr.arguments.length == 1) {
          compileExpr(ma.object);
          compileExpr(expr.arguments.first.value);
          emit(QudsOp.listAdd, 0, line);
          return;
        }
        if (ma.name == 'toStringAsFixed' && expr.arguments.length == 1) {
          compileExpr(ma.object);
          compileExpr(expr.arguments.first.value);
          emit(QudsOp.toFixed, 0, line);
          return;
        }
      }
      throw const _UnsupportedBytecode();
    }
    throw const _UnsupportedBytecode();
  }

  int? _matchIntrinsic(String name, int arity) {
    if (arity == 1) {
      return switch (name) {
        'sin' => _Intrinsic.sin,
        'cos' => _Intrinsic.cos,
        'tan' => _Intrinsic.tan,
        'sqrt' => _Intrinsic.sqrt,
        'abs' => _Intrinsic.abs,
        'exp' => _Intrinsic.exp,
        'log' => _Intrinsic.log,
        'floor' => _Intrinsic.floor,
        'ceil' => _Intrinsic.ceil,
        'round' => _Intrinsic.round,
        'double' => _Intrinsic.toDouble,
        'int' => _Intrinsic.toInt,
        _ => null,
      };
    }
    if (arity == 2) {
      return switch (name) {
        'pow' => _Intrinsic.pow,
        'min' => _Intrinsic.min,
        'max' => _Intrinsic.max,
        _ => null,
      };
    }
    return null;
  }
}

class _CallFrame {
  _CallFrame(this.fn, this.locals);
  final QudsBytecodeFunction fn;
  final List<Object?> locals;
  int ip = 0;
}

/// High-speed stack-based Bytecode Virtual Machine for Quds.
class QudsBytecodeVm {
  const QudsBytecodeVm._();

  /// Executes a compiled [QudsBytecodeProgram] honoring policy budgets.
  static QudsBytecodeRunResult run(
    QudsBytecodeProgram program, {
    int? maxSteps,
    int maxCallDepth = 256,
    Duration? timeout,
    void Function(String line)? onPrint,
  }) {
    final stopwatch = Stopwatch()..start();
    final printed = <String>[];
    final globals = List<Object?>.filled(program.globalNames.length, null);
    final stack = <Object?>[];
    final mainFn = program.functions[program.mainIndex];
    final frames = <_CallFrame>[
      _CallFrame(mainFn, List<Object?>.filled(mainFn.localCount, null)),
    ];
    var steps = 0;
    final timeoutMicros = timeout?.inMicroseconds;

    try {
      while (frames.isNotEmpty) {
        final frame = frames.last;
        final fn = frame.fn;
        final ops = fn.ops;
        final args = fn.operands;
        final consts = fn.constants;
        final locals = frame.locals;

        while (frame.ip < ops.length) {
          steps++;
          if (maxSteps != null && steps > maxSteps) {
            throw QudsPolicyViolationException(
              QudsPolicyViolationKind.stepLimit,
              'Bytecode VM exceeded maximum step limit ($maxSteps).',
              SourceSpan(fn.lines[frame.ip], 1, 1, file: program.file),
            );
          }
          if (timeoutMicros != null &&
              (steps & 4095) == 0 &&
              stopwatch.elapsedMicroseconds > timeoutMicros) {
            throw QudsPolicyViolationException(
              QudsPolicyViolationKind.timeout,
              'Bytecode VM execution timed out.',
              SourceSpan(fn.lines[frame.ip], 1, 1, file: program.file),
            );
          }

          final op = ops[frame.ip];
          final arg = args[frame.ip];
          frame.ip++;

          switch (op) {
            case QudsOp.pushConst:
              stack.add(consts[arg]);
            case QudsOp.pop:
              stack.removeLast();
            case QudsOp.dup:
              stack.add(stack.last);
            case QudsOp.loadLocal:
              stack.add(locals[arg]);
            case QudsOp.storeLocal:
              locals[arg] = stack.removeLast();
            case QudsOp.loadGlobal:
              stack.add(globals[arg]);
            case QudsOp.storeGlobal:
              globals[arg] = stack.removeLast();
            case QudsOp.add:
              final b = stack.removeLast();
              final a = stack.removeLast();
              if (a is num && b is num) {
                stack.add(a + b);
              } else {
                stack.add('${qudsFormatValue(a)}${qudsFormatValue(b)}');
              }
            case QudsOp.sub:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a - b);
            case QudsOp.mul:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a * b);
            case QudsOp.div:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a / b);
            case QudsOp.idiv:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a ~/ b);
            case QudsOp.mod:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a % b);
            case QudsOp.neg:
              stack[stack.length - 1] = -(stack.last! as num);
            case QudsOp.eq:
              final b = stack.removeLast();
              final a = stack.removeLast();
              stack.add(a == b);
            case QudsOp.neq:
              final b = stack.removeLast();
              final a = stack.removeLast();
              stack.add(a != b);
            case QudsOp.lt:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a < b);
            case QudsOp.lte:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a <= b);
            case QudsOp.gt:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a > b);
            case QudsOp.gte:
              final b = stack.removeLast()! as num;
              final a = stack.removeLast()! as num;
              stack.add(a >= b);
            case QudsOp.not:
              stack[stack.length - 1] = !(stack.last! as bool);
            case QudsOp.jump:
              frame.ip = arg;
            case QudsOp.jumpIfFalse:
              if (stack.removeLast() != true) frame.ip = arg;
            case QudsOp.jumpIfTrue:
              if (stack.removeLast() == true) frame.ip = arg;
            case QudsOp.callFn:
              if (frames.length >= maxCallDepth) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.callDepth,
                  'Bytecode VM exceeded maximum call depth ($maxCallDepth).',
                  SourceSpan(fn.lines[frame.ip - 1], 1, 1, file: program.file),
                );
              }
              final callee = program.functions[arg];
              final newLocals = List<Object?>.filled(callee.localCount, null);
              for (var i = callee.arity - 1; i >= 0; i--) {
                newLocals[i] = stack.removeLast();
              }
              frames.add(_CallFrame(callee, newLocals));
              break;
            case QudsOp.ret:
              final retVal = stack.removeLast();
              frames.removeLast();
              stack.add(retVal);
              break;
            case QudsOp.printTop:
              final text = qudsFormatValue(stack.removeLast());
              printed.add(text);
              onPrint?.call(text);
            case QudsOp.buildList:
              final list = List<Object?>.filled(arg, null, growable: true);
              for (var i = arg - 1; i >= 0; i--) {
                list[i] = stack.removeLast();
              }
              stack.add(list);
            case QudsOp.indexGet:
              final idx = (stack.removeLast()! as num).toInt();
              final obj = stack.removeLast();
              if (obj is List) {
                stack.add(obj[idx]);
              } else if (obj is String) {
                stack.add(obj[idx]);
              } else {
                throw QudsRuntimeException(
                  'Cannot index `${qudsTypeName(obj)}`.',
                  SourceSpan(fn.lines[frame.ip - 1], 1, 1, file: program.file),
                );
              }
            case QudsOp.indexSet:
              final val = stack.removeLast();
              final idx = (stack.removeLast()! as num).toInt();
              final list = stack.removeLast()! as List;
              list[idx] = val;
            case QudsOp.listLen:
              final obj = stack.removeLast();
              stack.add(obj is List ? obj.length : (obj as String).length);
            case QudsOp.listAdd:
              final val = stack.removeLast();
              final list = stack.removeLast()! as List;
              list.add(val);
              stack.add(null);
            case QudsOp.concatStr:
              final parts = List<String>.filled(arg, '');
              for (var i = arg - 1; i >= 0; i--) {
                parts[i] = qudsFormatValue(stack.removeLast());
              }
              stack.add(parts.join());
            case QudsOp.toFixed:
              final digits = (stack.removeLast()! as num).toInt();
              final val = stack.removeLast()! as num;
              stack.add(val.toStringAsFixed(digits));
            case QudsOp.callIntrinsic:
              switch (arg) {
                case _Intrinsic.sin:
                  stack[stack.length - 1] =
                      math.sin((stack.last! as num).toDouble());
                case _Intrinsic.cos:
                  stack[stack.length - 1] =
                      math.cos((stack.last! as num).toDouble());
                case _Intrinsic.tan:
                  stack[stack.length - 1] =
                      math.tan((stack.last! as num).toDouble());
                case _Intrinsic.sqrt:
                  stack[stack.length - 1] =
                      math.sqrt((stack.last! as num).toDouble());
                case _Intrinsic.abs:
                  stack[stack.length - 1] = (stack.last! as num).abs();
                case _Intrinsic.exp:
                  stack[stack.length - 1] =
                      math.exp((stack.last! as num).toDouble());
                case _Intrinsic.log:
                  stack[stack.length - 1] =
                      math.log((stack.last! as num).toDouble());
                case _Intrinsic.floor:
                  stack[stack.length - 1] = (stack.last! as num).floor();
                case _Intrinsic.ceil:
                  stack[stack.length - 1] = (stack.last! as num).ceil();
                case _Intrinsic.round:
                  stack[stack.length - 1] = (stack.last! as num).round();
                case _Intrinsic.toDouble:
                  stack[stack.length - 1] = (stack.last! as num).toDouble();
                case _Intrinsic.toInt:
                  stack[stack.length - 1] = (stack.last! as num).toInt();
                case _Intrinsic.pow:
                  final b = stack.removeLast()! as num;
                  final a = stack.removeLast()! as num;
                  stack.add(math.pow(a, b).toDouble());
                case _Intrinsic.min:
                  final b = stack.removeLast()! as num;
                  final a = stack.removeLast()! as num;
                  stack.add(math.min(a, b));
                case _Intrinsic.max:
                  final b = stack.removeLast()! as num;
                  final a = stack.removeLast()! as num;
                  stack.add(math.max(a, b));
              }
            case QudsOp.halt:
              stopwatch.stop();
              final val = stack.isEmpty ? null : stack.last;
              return QudsBytecodeRunResult(
                succeeded: true,
                value: val,
                printedLines: List.unmodifiable(printed),
                stepsExecuted: steps,
                elapsed: stopwatch.elapsed,
                globals: {
                  for (var i = 0; i < program.globalNames.length; i++)
                    program.globalNames[i]: globals[i],
                },
              );
          }

          if (!identical(frames.last, frame)) {
            // Frame pushed (callFn) or popped (ret) — switch outer dispatch loop.
            break;
          }
        }
      }

      stopwatch.stop();
      return QudsBytecodeRunResult(
        succeeded: true,
        value: stack.isEmpty ? null : stack.last,
        printedLines: List.unmodifiable(printed),
        stepsExecuted: steps,
        elapsed: stopwatch.elapsed,
        globals: {
          for (var i = 0; i < program.globalNames.length; i++)
            program.globalNames[i]: globals[i],
        },
      );
    } catch (err) {
      stopwatch.stop();
      return QudsBytecodeRunResult(
        succeeded: false,
        printedLines: List.unmodifiable(printed),
        stepsExecuted: steps,
        elapsed: stopwatch.elapsed,
        error: err,
      );
    }
  }
}
