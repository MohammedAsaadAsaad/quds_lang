/// Universal General-Purpose Register Bytecode Compiler & Virtual Machine
/// (`QudsUniversalVm`) supporting 100% of Quds 1.2 language semantics.
///
/// Pure Dart (zero `dart:io` or FFI). Uses ~24 general-purpose register opcodes
/// (`LOAD_CONST`, `LOAD_ENV`, `BIND_VAR`, `BINARY_OP`, `UNARY_OP`, `GET_MEMBER`,
/// `SET_MEMBER`, `GET_INDEX`, `SET_INDEX`, `CALL_ANY`, `CALL_MEMBER`,
/// `MAKE_LIST`, `MAKE_MAP`, `MAKE_SET`, `MAKE_STRING`, `JUMP`, `JUMP_IF_FALSE`,
/// `JUMP_IF_TRUE`, `PUSH_SCOPE`, `POP_SCOPE`, `EXEC_IMPORT`, `EXEC_RUNTIME_STMT`,
/// `EVAL_RUNTIME_EXPR`, `HALT`) — with zero library-specific opcodes so any
/// current or future library (`quds:viz`, `quds:math`, `quds:data`, `quds:core`,
/// host bridges, or user workspaces) executes natively.
///
/// Additionally performs **automatic Tier-1 promotion**: any pure-compute
/// top-level functions inside general scripts (such as physics or math kernels
/// inside `quds:viz` animations) are automatically compiled to unboxed
/// `Int64List`/`Float64List` 3-address register bytecode via
/// [QudsBytecodeCompiler.tryCompilePureFunctions].
library;

import 'dart:async';
import 'dart:typed_data';

import '../ast.dart';
import '../source.dart';
import 'bytecode_vm.dart';
import 'environment.dart';
import 'evaluator.dart';
import 'exceptions.dart';
import 'values.dart';

/// General-purpose 4-word register opcodes for [QudsUniversalVm].
abstract final class QudsUniversalOp {
  static const int halt = 0;
  static const int loadConst = 1;
  static const int move = 2;
  static const int loadEnv = 3;
  static const int bindVar = 4;
  static const int assignCompound = 5;
  static const int binaryOp = 6;
  static const int unaryOp = 7;
  static const int jump = 8;
  static const int jumpIfFalse = 9;
  static const int jumpIfTrue = 10;
  static const int jumpIfPresent = 11;
  static const int getMember = 12;
  static const int setMember = 13;
  static const int getIndex = 14;
  static const int setIndex = 15;
  static const int callAny = 16;
  static const int callMember = 17;
  static const int makeList = 18;
  static const int makeMap = 19;
  static const int makeSet = 20;
  static const int makeString = 21;
  static const int pushScope = 22;
  static const int popScope = 23;
  static const int execImport = 24;
  static const int execRuntimeStmt = 25;
  static const int evalRuntimeExpr = 26;
  static const int setLastExpr = 27;
  static const int expectBool = 28;
  static const int deferExpr = 29;
}

class _BindSpec {
  const _BindSpec(this.name, this.mode, this.declaredType, this.open);
  final String name;
  final BindingMode mode;
  final String? declaredType;
  final bool open;
}

class _MemberSpec {
  const _MemberSpec(this.name, this.nullAware);
  final String name;
  final bool nullAware;
}

class _MemberAssignSpec {
  const _MemberAssignSpec(this.name, this.operator);
  final String name;
  final String operator;
}

class _CallArgSpec {
  const _CallArgSpec(
      this.startReg, this.names, this.isSpread, this.nullAwareSpread);
  final int startReg;
  final List<String?> names;
  final List<bool> isSpread;
  final List<bool> nullAwareSpread;
}

class _MemberCallSpec {
  const _MemberCallSpec(this.name, this.nullAware, this.argSpec);
  final String name;
  final bool nullAware;
  final _CallArgSpec argSpec;
}

/// Compiled general-purpose register bytecode chunk for a Quds program.
class QudsUniversalChunk {
  const QudsUniversalChunk({
    required this.name,
    required this.code,
    required this.constants,
    required this.spans,
    required this.numRegs,
    required this.hoistedStatements,
    required this.mathPrefixes,
  });

  final String name;
  final Int32List code;
  final List<Object?> constants;
  final List<SourceSpan> spans;
  final int numRegs;
  final List<Statement> hoistedStatements;
  final Set<String> mathPrefixes;
}

/// Compiles any Quds [Program] AST (100% coverage) into [QudsUniversalChunk].
class QudsUniversalCompiler {
  QudsUniversalCompiler._();

  final List<int> _code = [];
  final List<Object?> _constants = [];
  final List<SourceSpan> _spans = [];
  final Set<String> _mathPrefixes = {};
  int _nextReg = 0;
  int _maxReg = 1;

  /// Compiles [program] unconditionally into universal register bytecode.
  static QudsUniversalChunk compile(
    Program program, {
    String name = '<main>',
  }) {
    final compiler = QudsUniversalCompiler._();
    compiler._compileProgram(program);
    return QudsUniversalChunk(
      name: name,
      code: Int32List.fromList(compiler._code),
      constants: List.unmodifiable(compiler._constants),
      spans: List.unmodifiable(compiler._spans),
      numRegs: compiler._maxReg,
      hoistedStatements: program.statements,
      mathPrefixes: Set.unmodifiable(compiler._mathPrefixes),
    );
  }

  int _allocReg() {
    final r = _nextReg++;
    if (_nextReg > _maxReg) _maxReg = _nextReg;
    return r;
  }

  int _allocContiguous(int count) {
    final start = _nextReg;
    _nextReg += count;
    if (_nextReg > _maxReg) _maxReg = _nextReg;
    return start;
  }

  int _addConst(Object? val) {
    _constants.add(val);
    return _constants.length - 1;
  }

  int _emit(int op, int dst, int a, int b, SourceSpan span) {
    final pc = _code.length;
    _code.add(op);
    _code.add(dst);
    _code.add(a);
    _code.add(b);
    _spans.add(span);
    return pc;
  }

  void _patchJump(int pc, int targetPc) {
    _code[pc + 2] = targetPc;
  }

  void _compileProgram(Program program) {
    for (final stmt in program.statements) {
      if (stmt is ImportDeclaration &&
          (stmt.uri == 'dart:math' || stmt.uri == 'quds:math') &&
          stmt.prefix != null) {
        _mathPrefixes.add(stmt.prefix!);
      }
      _compileStatement(stmt, recordLastExpr: true);
    }
    _emit(QudsUniversalOp.halt, 0, 0, 0, program.span);
  }

  void _compileBlock(List<Statement> stmts, SourceSpan span) {
    _emit(QudsUniversalOp.pushScope, 0, 0, 0, span);
    for (final stmt in stmts) {
      _compileStatement(stmt, recordLastExpr: false);
    }
    _emit(QudsUniversalOp.popScope, 0, 0, 0, span);
  }

  void _compileStatement(Statement stmt, {required bool recordLastExpr}) {
    final savedReg = _nextReg;
    switch (stmt) {
      case FunctionDeclaration():
      case SectionDeclaration():
      case AliasDeclaration():
      case PartDirective():
      case AnnotationDeclaration():
        // Top-level functions are hoisted before execution; directives are no-ops.
        break;

      case ImportDeclaration():
        final k = _addConst(stmt);
        _emit(QudsUniversalOp.execImport, 0, k, 0, stmt.span);

      case DeferStatement(:final expression):
        final k = _addConst(expression);
        _emit(QudsUniversalOp.deferExpr, 0, k, 0, stmt.span);

      case ExpressionStatement(:final expression):
        final r = _compileExpr(expression);
        if (recordLastExpr) {
          _emit(QudsUniversalOp.setLastExpr, r, 0, 0, stmt.span);
        }

      case Binding():
        if (stmt.mode == BindingMode.computed ||
            stmt.value is DotShorthand ||
            stmt.operator == '??=') {
          final k = _addConst(stmt);
          _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
        } else if (stmt.operator == '=') {
          final valReg = stmt.open ? _allocReg() : _compileExpr(stmt.value);
          final specIdx = _addConst(
            _BindSpec(stmt.name, stmt.mode, stmt.type, stmt.open),
          );
          _emit(QudsUniversalOp.bindVar, valReg, specIdx, 0, stmt.span);
        } else {
          final rhsReg = _compileExpr(stmt.value);
          final nameIdx = _addConst(stmt.name);
          final opIdx = _addConst(stmt.operator);
          _emit(
            QudsUniversalOp.assignCompound,
            rhsReg,
            nameIdx,
            opIdx,
            stmt.span,
          );
        }

      case MemberAssignment(
          :final object,
          :final name,
          :final operator,
          :final value
        ):
        if (operator == '??=') {
          final k = _addConst(stmt);
          _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
        } else {
          final objReg = _compileExpr(object);
          final valReg = _compileExpr(value);
          final specIdx = _addConst(_MemberAssignSpec(name, operator));
          _emit(QudsUniversalOp.setMember, objReg, valReg, specIdx, stmt.span);
        }

      case IndexAssignment(:final target, :final operator, :final value):
        if (operator == '??=') {
          final k = _addConst(stmt);
          _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
        } else {
          final objReg = _compileExpr(target.object);
          final idxReg = _compileExpr(target.index);
          final valReg = _compileExpr(value);
          final opIdx = _addConst(operator);
          // Pack (idxReg, opIdx) via constant tuple to stay in 4-word format.
          final metaIdx = _addConst((idxReg, opIdx));
          _emit(QudsUniversalOp.setIndex, objReg, valReg, metaIdx, stmt.span);
        }

      case IfStatement(:final condition, :final thenBody, :final elseBody):
        if (_blockNeedsRuntimeFallback(thenBody) ||
            _blockNeedsRuntimeFallback(elseBody)) {
          final k = _addConst(stmt);
          _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
        } else {
          final condReg = _compileExpr(condition);
          final jFalse = _emit(
            QudsUniversalOp.jumpIfFalse,
            condReg,
            0,
            0,
            condition.span,
          );
          _compileBlock(thenBody, stmt.span);
          if (elseBody.isNotEmpty) {
            final jEnd = _emit(QudsUniversalOp.jump, 0, 0, 0, stmt.span);
            _patchJump(jFalse, _code.length);
            _compileBlock(elseBody, stmt.span);
            _patchJump(jEnd, _code.length);
          } else {
            _patchJump(jFalse, _code.length);
          }
        }

      case WhenStatement(:final condition, :final body):
        if (_blockNeedsRuntimeFallback(body)) {
          final k = _addConst(stmt);
          _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
        } else {
          final condReg = _compileExpr(condition);
          final jFalse = _emit(
            QudsUniversalOp.jumpIfFalse,
            condReg,
            0,
            0,
            condition.span,
          );
          _compileBlock(body, stmt.span);
          _patchJump(jFalse, _code.length);
        }

      case GuardStatement(:final condition, :final elseBody):
        if (_blockNeedsRuntimeFallback(elseBody)) {
          final k = _addConst(stmt);
          _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
        } else {
          final condReg = _compileExpr(condition);
          final jTrue = _emit(
            QudsUniversalOp.jumpIfTrue,
            condReg,
            0,
            0,
            condition.span,
          );
          _compileBlock(elseBody, stmt.span);
          _patchJump(jTrue, _code.length);
        }

      default:
        // Loops (with $ context / break / continue / labels / else),
        // classes, extensions, try/catch/finally, match, reactive, events,
        // generators, task groups, config, test, etc. run via the runtime bridge.
        final k = _addConst(stmt);
        _emit(QudsUniversalOp.execRuntimeStmt, 0, k, 0, stmt.span);
    }
    _nextReg = savedReg;
  }

  /// Checks whether a nested block declares local functions or `defer`
  /// statements that require block-level hoisting / LIFO cleanup.
  bool _blockNeedsRuntimeFallback(List<Statement> stmts) {
    for (final s in stmts) {
      if (s is FunctionDeclaration || s is DeferStatement) return true;
    }
    return false;
  }

  int _compileExpr(Expression expr) {
    switch (expr) {
      case Literal(:final value):
        final dst = _allocReg();
        final k = _addConst(value);
        _emit(QudsUniversalOp.loadConst, dst, k, 0, expr.span);
        return dst;

      case DurationLiteral(:final microseconds):
        final dst = _allocReg();
        final k = _addConst(Duration(microseconds: microseconds));
        _emit(QudsUniversalOp.loadConst, dst, k, 0, expr.span);
        return dst;

      case Identifier(:final name):
        final dst = _allocReg();
        if (name == 'missing') {
          final k = _addConst(QudsMissing.instance);
          _emit(QudsUniversalOp.loadConst, dst, k, 0, expr.span);
        } else {
          final k = _addConst(name);
          _emit(QudsUniversalOp.loadEnv, dst, k, 0, expr.span);
        }
        return dst;

      case ThisExpression():
        final dst = _allocReg();
        final k = _addConst('this');
        _emit(QudsUniversalOp.loadEnv, dst, k, 0, expr.span);
        return dst;

      case UnaryExpression(:final operator, :final operand):
        final src = _compileExpr(operand);
        final dst = _allocReg();
        final opIdx = _addConst(operator);
        _emit(QudsUniversalOp.unaryOp, dst, src, opIdx, expr.span);
        return dst;

      case BinaryExpression(:final left, :final operator, :final right):
        if (operator == '&&' || operator == 'and') {
          final dst = _allocReg();
          final lReg = _compileExpr(left);
          _emit(QudsUniversalOp.expectBool, lReg, 0, 0, left.span);
          _emit(QudsUniversalOp.move, dst, lReg, 0, left.span);
          final jFalse =
              _emit(QudsUniversalOp.jumpIfFalse, lReg, 0, 0, left.span);
          final rReg = _compileExpr(right);
          _emit(QudsUniversalOp.expectBool, rReg, 0, 0, right.span);
          _emit(QudsUniversalOp.move, dst, rReg, 0, right.span);
          _patchJump(jFalse, _code.length);
          return dst;
        }
        if (operator == '||' || operator == 'or') {
          final dst = _allocReg();
          final lReg = _compileExpr(left);
          _emit(QudsUniversalOp.expectBool, lReg, 0, 0, left.span);
          _emit(QudsUniversalOp.move, dst, lReg, 0, left.span);
          final jTrue =
              _emit(QudsUniversalOp.jumpIfTrue, lReg, 0, 0, left.span);
          final rReg = _compileExpr(right);
          _emit(QudsUniversalOp.expectBool, rReg, 0, 0, right.span);
          _emit(QudsUniversalOp.move, dst, rReg, 0, right.span);
          _patchJump(jTrue, _code.length);
          return dst;
        }
        if (operator == '??') {
          final dst = _allocReg();
          final lReg = _compileExpr(left);
          _emit(QudsUniversalOp.move, dst, lReg, 0, left.span);
          final jPresent =
              _emit(QudsUniversalOp.jumpIfPresent, lReg, 0, 0, left.span);
          final rReg = _compileExpr(right);
          _emit(QudsUniversalOp.move, dst, rReg, 0, right.span);
          _patchJump(jPresent, _code.length);
          return dst;
        }
        final lReg = _compileExpr(left);
        final rReg = _compileExpr(right);
        final dst = _allocReg();
        final meta = _addConst((rReg, operator));
        _emit(QudsUniversalOp.binaryOp, dst, lReg, meta, expr.span);
        return dst;

      case IfExpression(:final condition, :final thenValue, :final elseValue):
        final dst = _allocReg();
        final condReg = _compileExpr(condition);
        final jFalse =
            _emit(QudsUniversalOp.jumpIfFalse, condReg, 0, 0, condition.span);
        final thenReg = _compileExpr(thenValue);
        _emit(QudsUniversalOp.move, dst, thenReg, 0, thenValue.span);
        final jEnd = _emit(QudsUniversalOp.jump, 0, 0, 0, expr.span);
        _patchJump(jFalse, _code.length);
        final elseReg = _compileExpr(elseValue);
        _emit(QudsUniversalOp.move, dst, elseReg, 0, elseValue.span);
        _patchJump(jEnd, _code.length);
        return dst;

      case MemberAccess(:final object, :final name, :final nullAware):
        final objReg = _compileExpr(object);
        final dst = _allocReg();
        final specIdx = _addConst(_MemberSpec(name, nullAware));
        _emit(QudsUniversalOp.getMember, dst, objReg, specIdx, expr.span);
        return dst;

      case IndexExpression(:final object, :final index):
        final objReg = _compileExpr(object);
        final idxReg = _compileExpr(index);
        final dst = _allocReg();
        _emit(QudsUniversalOp.getIndex, dst, objReg, idxReg, expr.span);
        return dst;

      case TypeApplication(:final callee):
        return _compileExpr(callee);

      case InterpolatedString(:final parts):
        final start = _allocContiguous(parts.length);
        for (var i = 0; i < parts.length; i++) {
          final r = _compileExpr(parts[i]);
          _emit(QudsUniversalOp.move, start + i, r, 0, parts[i].span);
        }
        final dst = _allocReg();
        _emit(QudsUniversalOp.makeString, dst, start, parts.length, expr.span);
        return dst;

      case ListExpression(:final elements, :final nullAware):
        final hasSpecial = nullAware.any((e) => e) ||
            elements.any((e) =>
                e is SpreadElement ||
                e is NullAwareElement ||
                e is CollectionIf ||
                e is CollectionFor);
        if (hasSpecial) {
          final dst = _allocReg();
          final k = _addConst(expr);
          _emit(QudsUniversalOp.evalRuntimeExpr, dst, k, 0, expr.span);
          return dst;
        }
        final start = _allocContiguous(elements.length);
        for (var i = 0; i < elements.length; i++) {
          final r = _compileExpr(elements[i]);
          _emit(QudsUniversalOp.move, start + i, r, 0, elements[i].span);
        }
        final dst = _allocReg();
        _emit(QudsUniversalOp.makeList, dst, start, elements.length, expr.span);
        return dst;

      case SetExpression(:final elements, :final nullAware):
        final hasSpecial = nullAware.any((e) => e) ||
            elements.any((e) =>
                e is SpreadElement ||
                e is NullAwareElement ||
                e is CollectionIf ||
                e is CollectionFor);
        if (hasSpecial) {
          final dst = _allocReg();
          final k = _addConst(expr);
          _emit(QudsUniversalOp.evalRuntimeExpr, dst, k, 0, expr.span);
          return dst;
        }
        final start = _allocContiguous(elements.length);
        for (var i = 0; i < elements.length; i++) {
          final r = _compileExpr(elements[i]);
          _emit(QudsUniversalOp.move, start + i, r, 0, elements[i].span);
        }
        final dst = _allocReg();
        _emit(QudsUniversalOp.makeSet, dst, start, elements.length, expr.span);
        return dst;

      case MapExpression(:final keys, :final values):
        final count = keys.length;
        final start = _allocContiguous(count * 2);
        for (var i = 0; i < count; i++) {
          final kr = _compileExpr(keys[i]);
          _emit(QudsUniversalOp.move, start + i * 2, kr, 0, keys[i].span);
          final vr = _compileExpr(values[i]);
          _emit(QudsUniversalOp.move, start + i * 2 + 1, vr, 0, values[i].span);
        }
        final dst = _allocReg();
        _emit(QudsUniversalOp.makeMap, dst, start, count, expr.span);
        return dst;

      case CallExpression(:final callee, :final arguments):
        if (callee is MemberAccess) {
          final recvReg = _compileExpr(callee.object);
          final argSpec = _compileCallArgs(arguments);
          final dst = _allocReg();
          final specIdx = _addConst(
            _MemberCallSpec(callee.name, callee.nullAware, argSpec),
          );
          _emit(QudsUniversalOp.callMember, dst, recvReg, specIdx, expr.span);
          return dst;
        }
        final calleeReg = _compileExpr(callee);
        final argSpec = _compileCallArgs(arguments);
        final dst = _allocReg();
        final specIdx = _addConst(argSpec);
        _emit(QudsUniversalOp.callAny, dst, calleeReg, specIdx, expr.span);
        return dst;

      default:
        final dst = _allocReg();
        final k = _addConst(expr);
        _emit(QudsUniversalOp.evalRuntimeExpr, dst, k, 0, expr.span);
        return dst;
    }
  }

  _CallArgSpec _compileCallArgs(List<Argument> arguments) {
    final start = _allocContiguous(arguments.length);
    final names = <String?>[];
    final isSpread = <bool>[];
    final nullAwareSpread = <bool>[];
    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];
      names.add(arg.name);
      if (arg.name == null && arg.value is SpreadElement) {
        final sp = arg.value as SpreadElement;
        isSpread.add(true);
        nullAwareSpread.add(sp.nullAware);
        final r = _compileExpr(sp.operand);
        _emit(QudsUniversalOp.move, start + i, r, 0, sp.span);
      } else {
        isSpread.add(false);
        nullAwareSpread.add(false);
        final r = _compileExpr(arg.value);
        _emit(QudsUniversalOp.move, start + i, r, 0, arg.value.span);
      }
    }
    return _CallArgSpec(start, names, isSpread, nullAwareSpread);
  }
}

/// General-Purpose Register Bytecode Virtual Machine executing 100% of Quds.
class QudsUniversalVm {
  const QudsUniversalVm._();

  /// Executes [chunk] in [rootEnv] using [runtime] for shared Quds semantics
  /// and automatically promotes pure-compute top-level functions to Tier-1
  /// unboxed [QudsBytecodeVm] kernels when [enableTier1Promotion] is true.
  static Future<Object?> execute(
    QudsUniversalChunk chunk,
    QudsEvaluator runtime,
    QudsEnvironment rootEnv, {
    bool resetBudget = true,
    bool enableTier1Promotion = true,
  }) async {
    runtime.vmBeginRun(resetBudget: resetBudget);
    final deferred = <Expression>[];
    final regs = List<Object?>.filled(chunk.numRegs, null);
    final code = chunk.code;
    final constants = chunk.constants;
    final spans = chunk.spans;
    var env = rootEnv;
    Object? lastValue;

    try {
      // 1. Hoist all top-level functions (preserving E201 duplicate signature checks).
      runtime.vmHoistFunctions(chunk.hoistedStatements, rootEnv);

      // 2. Automatic Tier-1 unboxed register promotion for pure-compute functions!
      if (enableTier1Promotion) {
        final fnDecls =
            chunk.hoistedStatements.whereType<FunctionDeclaration>().toList();
        if (fnDecls.isNotEmpty) {
          final tier1 = QudsBytecodeCompiler.tryCompilePureFunctions(
            fnDecls,
            file: chunk.name,
            mathPrefixes: chunk.mathPrefixes,
          );
          if (tier1 != null) {
            for (var i = 0; i < tier1.functionDecls.length; i++) {
              final decl = tier1.functionDecls[i];
              final fallbackSlot = rootEnv.localSlots[decl.name];
              final fallbackFn = fallbackSlot?.value;
              if (fallbackFn is QudsUserFunction) {
                final promoted = QudsNativeFunction(
                  decl.name,
                  (pos, named, ctx) {
                    // Unified call syntax (named args) delegates seamlessly to fallback.
                    if (named.isNotEmpty) {
                      return runtime.invokeCallable(
                        fallbackFn,
                        pos,
                        named,
                        ctx.span,
                      );
                    }
                    final res = QudsBytecodeVm.invokeFunction(
                      tier1,
                      i,
                      pos,
                      maxSteps: runtime.maxSteps,
                      maxCallDepth: runtime.maxCallDepth,
                      maxCollectionLength: runtime.maxCollectionLength,
                      timeout: runtime.timeout,
                      onPrint: (line) => runtime.onPrint(line, ctx.span),
                    );
                    if (!res.succeeded) {
                      final err = res.error;
                      if (err is QudsPolicyViolationException) throw err;
                      if (err is QudsRuntimeException) throw err;
                      throw QudsRuntimeException('$err', ctx.span);
                    }
                    return res.value;
                  },
                  isSync: true,
                );
                fallbackSlot!.value = promoted;
              }
            }
          }
        }
      }

      // 3. Flat 4-word Register Bytecode Dispatch Loop!
      var pc = 0;
      final len = code.length;
      while (pc < len) {
        final op = code[pc];
        final dst = code[pc + 1];
        final a = code[pc + 2];
        final b = code[pc + 3];
        final span = spans[pc >> 2];
        pc += 4;

        final tick = runtime.vmTick(span);
        if (tick != null) await tick;

        switch (op) {
          case QudsUniversalOp.halt:
            return lastValue;

          case QudsUniversalOp.loadConst:
            regs[dst] = constants[a];

          case QudsUniversalOp.move:
            regs[dst] = regs[a];

          case QudsUniversalOp.loadEnv:
            regs[dst] = env.get(constants[a] as String, span);

          case QudsUniversalOp.bindVar:
            final spec = constants[a] as _BindSpec;
            env.bind(
              spec.name,
              spec.mode,
              spec.open ? null : regs[dst],
              span,
              declaredType: spec.declaredType,
              open: spec.open,
              allowMutation: runtime.allowMutation,
            );
            if (runtime.vmHasReactiveState) {
              await runtime.vmNotifyStateChanged();
            }

          case QudsUniversalOp.assignCompound:
            final name = constants[a] as String;
            final operator = constants[b] as String;
            final current = env.get(name, span);
            final baseOp = operator.substring(0, operator.length - 1);
            final r = runtime.vmApplyBinary(current, baseOp, regs[dst], span);
            final updated = r is Future<Object?> ? await r : r;
            env.assignExisting(
              name,
              updated,
              span,
              allowMutation: runtime.allowMutation,
            );
            if (runtime.vmHasReactiveState) {
              await runtime.vmNotifyStateChanged();
            }

          case QudsUniversalOp.binaryOp:
            final (rReg, operator) = constants[b] as (int, String);
            final r =
                runtime.vmApplyBinary(regs[a], operator, regs[rReg], span);
            regs[dst] = r is Future<Object?> ? await r : r;

          case QudsUniversalOp.unaryOp:
            final operator = constants[b] as String;
            regs[dst] = runtime.vmApplyUnary(operator, regs[a], span);

          case QudsUniversalOp.expectBool:
            runtime.vmExpectBool(regs[dst], span);

          case QudsUniversalOp.jump:
            pc = a;

          case QudsUniversalOp.jumpIfFalse:
            if (!runtime.vmExpectBool(regs[dst], span)) {
              pc = a;
            }

          case QudsUniversalOp.jumpIfTrue:
            if (runtime.vmExpectBool(regs[dst], span)) {
              pc = a;
            }

          case QudsUniversalOp.jumpIfPresent:
            final v = regs[dst];
            if (v != null && v is! QudsMissing) {
              pc = a;
            }

          case QudsUniversalOp.getMember:
            final spec = constants[b] as _MemberSpec;
            final r = runtime.vmEvalMemberRead(
                regs[a], spec.name, spec.nullAware, span);
            regs[dst] = r is Future<Object?> ? await r : r;

          case QudsUniversalOp.setMember:
            final spec = constants[b] as _MemberAssignSpec;
            await runtime.vmExecMemberAssign(
              regs[dst],
              spec.name,
              spec.operator,
              regs[a],
              env,
              span,
            );

          case QudsUniversalOp.getIndex:
            final r = runtime.vmEvalIndexRead(regs[a], regs[b], span);
            regs[dst] = r is Future<Object?> ? await r : r;

          case QudsUniversalOp.setIndex:
            final (idxReg, opIdx) = constants[b] as (int, int);
            await runtime.vmExecIndexAssign(
              regs[dst],
              regs[idxReg],
              constants[opIdx] as String,
              regs[a],
              span,
            );

          case QudsUniversalOp.callAny:
            final spec = constants[b] as _CallArgSpec;
            final (pos, named) = _unpackArgs(regs, spec, span);
            final r = runtime.vmInvokeCallable(regs[a], pos, named, span);
            regs[dst] = r is Future<Object?> ? await r : r;

          case QudsUniversalOp.callMember:
            final spec = constants[b] as _MemberCallSpec;
            final (pos, named) = _unpackArgs(regs, spec.argSpec, span);
            final r = runtime.vmInvokeMemberCall(
              regs[a],
              spec.name,
              spec.nullAware,
              pos,
              named,
              span,
            );
            regs[dst] = r is Future<Object?> ? await r : r;

          case QudsUniversalOp.makeList:
            final out = <Object?>[
              for (var i = 0; i < b; i++) regs[a + i],
            ];
            runtime.vmCheckCollectionSize(out.length, span);
            regs[dst] = out;

          case QudsUniversalOp.makeSet:
            final out = <Object?>{
              for (var i = 0; i < b; i++) regs[a + i],
            };
            runtime.vmCheckCollectionSize(out.length, span);
            regs[dst] = out;

          case QudsUniversalOp.makeMap:
            final out = <Object?, Object?>{};
            for (var i = 0; i < b; i++) {
              out[regs[a + i * 2]] = regs[a + i * 2 + 1];
            }
            runtime.vmCheckCollectionSize(out.length, span);
            regs[dst] = out;

          case QudsUniversalOp.makeString:
            final buf = StringBuffer();
            for (var i = 0; i < b; i++) {
              buf.write(qudsFormatValue(regs[a + i]));
              runtime.vmCheckStringLength(buf.length, span);
            }
            regs[dst] = buf.toString();

          case QudsUniversalOp.pushScope:
            env = env.child();

          case QudsUniversalOp.popScope:
            env = env.parent ?? rootEnv;

          case QudsUniversalOp.execImport:
            final imp = constants[a] as ImportDeclaration;
            await runtime.vmExecStatement(imp, env);

          case QudsUniversalOp.deferExpr:
            deferred.add(constants[a] as Expression);

          case QudsUniversalOp.execRuntimeStmt:
            final stmt = constants[a] as Statement;
            await runtime.vmExecStatement(stmt, env, alreadyHoisted: true);

          case QudsUniversalOp.evalRuntimeExpr:
            final expr = constants[a] as Expression;
            final r = runtime.vmEvalExpr(expr, env);
            regs[dst] = r is Future<Object?> ? await r : r;

          case QudsUniversalOp.setLastExpr:
            lastValue = regs[dst];
        }
      }
      return lastValue;
    } on ReturnSignal catch (ret) {
      return ret.value;
    } on QudsThrownValue catch (thrown) {
      throw QudsRuntimeException(
        'Uncaught exception: ${qudsFormatValue(thrown.value)}',
        thrown.span,
        code: 'R200',
        stackFrames: thrown.stackFrames,
        cause: thrown.value,
      );
    } finally {
      for (final expr in deferred.reversed) {
        final r = runtime.vmEvalExpr(expr, rootEnv);
        if (r is Future<Object?>) await r;
      }
      runtime.vmEndRun(resetBudget: resetBudget);
    }
  }

  static (List<Object?>, Map<String, Object?>) _unpackArgs(
    List<Object?> regs,
    _CallArgSpec spec,
    SourceSpan span,
  ) {
    final pos = <Object?>[];
    final named = <String, Object?>{};
    final count = spec.names.length;
    for (var i = 0; i < count; i++) {
      final v = regs[spec.startReg + i];
      final argName = spec.names[i];
      if (argName != null) {
        named[argName] = v;
      } else if (spec.isSpread[i]) {
        if (v is Iterable) {
          pos.addAll(v);
        } else if (v == null && spec.nullAwareSpread[i]) {
          continue;
        } else {
          throw QudsRuntimeException('Spread argument must be Iterable.', span);
        }
      } else {
        pos.add(v);
      }
    }
    return (pos, named);
  }
}
