/// High-Performance Typed 3-Address Register Bytecode Compiler & Virtual Machine
/// (`QudsBytecodeVm`) for accelerating compute-heavy Quds loops, recursion,
/// numerical methods, physics simulations, and algorithmic workloads.
///
/// Key architectural pillars (100% pure Dart, zero `dart:io` or FFI):
/// 1. **3-Address Register ISA** packed into flat `Int32List` (stride 2), cutting
///    instruction dispatch count by ~3–4x compared to stack-based bytecode.
/// 2. **Static Local Type Inference & Unboxed Register Banks**: inferred `int`
///    and `double` locals/temporaries execute directly in flat `Int64List` and
///    `Float64List` register files with **zero heap boxing**.
/// 3. **Unboxed Typed Lists (`_QudsIntList` / `_QudsFloatList`)**: inferred
///    numeric lists are backed by raw `Int64List` / `Float64List` buffers stored
///    in dedicated typed register banks — zero runtime type casts and zero
///    floating-point heap boxing on reads/writes!
/// 4. **Loop Constant Hoisting & Fused Multiply-Add (`fMulAdd`)**: numeric
///    constants in loop-bearing functions are hoisted once into prologue
///    registers, and `acc = acc + x * y` fuses into a single FMA-style op.
/// 5. **Zero-Allocation Flat Call Windows + Fast Self-Recursion**: function
///    calls advance register-window base pointers (`iBp`/`fBp`/`oBp`) with zero
///    heap allocations, and 1-int-arg self-recursion uses specialized
///    `callSelfI1Sub` + minimal 2-slot frame push.
/// 6. **Strict Policy Budgets**: airtight `maxSteps`, `maxCallDepth`, and
///    `timeout` enforcement on loop back-edges and calls, with transparent
///    fallback to the full AST evaluator when dynamic constructs are present.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../ast.dart';
import '../lexer.dart';
import '../parser.dart';
import 'exceptions.dart';
import 'values.dart';

/// Fast unboxed growable 64-bit integer list backed by [Int64List].
final class _QudsIntList {
  _QudsIntList() : data = Int64List(16);

  Int64List data;
  int length = 0;

  @pragma('vm:prefer-inline')
  Int64List grow() {
    final len = length;
    final grown = Int64List(len << 1);
    grown.setRange(0, len, data);
    data = grown;
    return grown;
  }

  @pragma('vm:prefer-inline')
  void add(int value) {
    final len = length;
    var buf = data;
    if (len == buf.length) buf = grow();
    buf[len] = value;
    length = len + 1;
  }

  List<int> toDartList() => data.sublist(0, length);
}

/// Fast unboxed growable 64-bit float list backed by [Float64List].
final class _QudsFloatList {
  _QudsFloatList() : data = Float64List(16);

  Float64List data;
  int length = 0;

  @pragma('vm:prefer-inline')
  Float64List grow() {
    final len = length;
    final grown = Float64List(len << 1);
    grown.setRange(0, len, data);
    data = grown;
    return grown;
  }

  @pragma('vm:prefer-inline')
  void add(double value) {
    final len = length;
    var buf = data;
    if (len == buf.length) buf = grow();
    buf[len] = value;
    length = len + 1;
  }

  List<double> toDartList() => data.sublist(0, length);
}

/// Compact 3-address register opcodes for [QudsBytecodeVm].
abstract final class QudsOp {
  // Control & Calls (0..9)
  static const int halt = 0;
  static const int jump = 1;
  static const int callFn = 2;
  static const int callFnI1 = 3;
  static const int callSelfI1Sub = 4;
  static const int retI = 5;
  static const int retF = 6;
  static const int retO = 7;
  static const int retVoid = 8;
  static const int retSelfI = 9;

  // Unboxed Int64 Register Ops (10..31)
  static const int iLoadK = 10;
  static const int iLoadImm = 11;
  static const int iMove = 12;
  static const int iAdd = 13;
  static const int iAddImm = 14;
  static const int iSub = 15;
  static const int iMul = 16;
  static const int iDivF = 17;
  static const int iIdiv = 18;
  static const int iMod = 19;
  static const int iNeg = 20;
  static const int iJge = 21;
  static const int iJgt = 22;
  static const int iJle = 23;
  static const int iJlt = 24;
  static const int iJne = 25;
  static const int iJeq = 26;
  static const int iJgtK = 27;
  static const int iJgeK = 28;
  static const int iJltK = 29;
  static const int iJleK = 30;
  static const int iJneK = 31;

  // Unboxed Float64 Register Ops (32..50)
  static const int fLoadK = 32;
  static const int fMove = 33;
  static const int fAdd = 34;
  static const int fSub = 35;
  static const int fMul = 36;
  static const int fDiv = 37;
  static const int fNeg = 38;
  static const int fMulAdd = 39;
  static const int fSqrt = 40;
  static const int fIntrinsic = 41;
  static const int fIntrinsic2 = 42;
  static const int fJgt = 43;
  static const int fJge = 44;
  static const int fJlt = 45;
  static const int fJle = 46;
  static const int fJgtK = 47;
  static const int iToF = 48;
  static const int fToI = 49;
  static const int iJeqK = 50;

  // Unboxed Typed & Dynamic List Ops (51..66)
  static const int newIntList = 51;
  static const int newFloatList = 52;
  static const int newObjList = 53;
  static const int intListAdd = 54;
  static const int intListGet = 55;
  static const int intListSet = 56;
  static const int intListLen = 57;
  static const int floatListAdd = 58;
  static const int floatListGet = 59;
  static const int floatListSet = 60;
  static const int floatListLen = 61;
  static const int objListAdd = 62;
  static const int objListGet = 63;
  static const int objListSet = 64;
  static const int objListLen = 65;
  static const int intListToO = 66;

  // Boxing, Globals, Dynamic Ops, Strings & IO (67..86)
  static const int floatListToO = 67;
  static const int iToO = 68;
  static const int fToO = 69;
  static const int oToI = 70;
  static const int oToF = 71;
  static const int oLoadK = 72;
  static const int oMove = 73;
  static const int oLoadGlobal = 74;
  static const int oStoreGlobal = 75;
  static const int oBinOp = 76;
  static const int oUnaryOp = 77;
  static const int oJumpIfFalse = 78;
  static const int oJumpIfTrue = 79;
  static const int concatStr = 80;
  static const int toFixed = 81;
  static const int printI = 82;
  static const int printF = 83;
  static const int printO = 84;
  static const int iCmpToO = 85;
  static const int fCmpToO = 86;
  static const int iIncJump = 87;
  static const int iAddJump = 88;
  static const int iIncJlt = 89;
  static const int iIncJle = 90;
  static const int iAddListGet = 91;

  static const List<String> names = [
    'HALT',
    'JUMP',
    'CALL_FN',
    'CALL_FN_I1',
    'CALL_FN_SELF_I1_SUB',
    'RET_I',
    'RET_F',
    'RET_O',
    'RET_VOID',
    'RET_SELF_I',
    'I_LOAD_K',
    'I_LOAD_IMM',
    'I_MOVE',
    'I_ADD',
    'I_ADD_IMM',
    'I_SUB',
    'I_MUL',
    'I_DIV_F',
    'I_IDIV',
    'I_MOD',
    'I_NEG',
    'I_JGE',
    'I_JGT',
    'I_JLE',
    'I_JLT',
    'I_JNE',
    'I_JEQ',
    'I_JGT_K',
    'I_JGE_K',
    'I_JLT_K',
    'I_JLE_K',
    'I_JNE_K',
    'F_LOAD_K',
    'F_MOVE',
    'F_ADD',
    'F_SUB',
    'F_MUL',
    'F_DIV',
    'F_NEG',
    'F_MUL_ADD',
    'F_SQRT',
    'F_INTRINSIC',
    'F_INTRINSIC2',
    'F_JGT',
    'F_JGE',
    'F_Jlt',
    'F_JLE',
    'F_JGT_K',
    'I_TO_F',
    'F_TO_I',
    'I_JEQ_K',
    'NEW_INT_LIST',
    'NEW_FLOAT_LIST',
    'NEW_OBJ_LIST',
    'INT_LIST_ADD',
    'INT_LIST_GET',
    'INT_LIST_SET',
    'INT_LIST_LEN',
    'FLOAT_LIST_ADD',
    'FLOAT_LIST_GET',
    'FLOAT_LIST_SET',
    'FLOAT_LIST_LEN',
    'OBJ_LIST_ADD',
    'OBJ_LIST_GET',
    'OBJ_LIST_SET',
    'OBJ_LIST_LEN',
    'INT_LIST_TO_O',
    'FLOAT_LIST_TO_O',
    'I_TO_O',
    'F_TO_O',
    'O_TO_I',
    'O_TO_F',
    'O_LOAD_K',
    'O_MOVE',
    'O_LOAD_GLOBAL',
    'O_STORE_GLOBAL',
    'O_BIN_OP',
    'O_UNARY_OP',
    'O_JMP_IF_FALSE',
    'O_JMP_IF_TRUE',
    'CONCAT_STR',
    'TO_FIXED',
    'PRINT_I',
    'PRINT_F',
    'PRINT_O',
    'I_CMP_TO_O',
    'F_CMP_TO_O',
    'I_INC_JUMP',
    'I_ADD_JUMP',
    'I_INC_JLT',
    'I_INC_JLE',
    'I_ADD_LIST_GET',
  ];
}

abstract final class _Intr {
  static const int sin = 0;
  static const int cos = 1;
  static const int tan = 2;
  static const int abs = 3;
  static const int exp = 4;
  static const int log = 5;
  static const int floor = 6;
  static const int ceil = 7;
  static const int round = 8;
  static const int pow = 9;
  static const int min = 10;
  static const int max = 11;
}

abstract final class _DynBinOp {
  static const int add = 0;
  static const int sub = 1;
  static const int mul = 2;
  static const int div = 3;
  static const int idiv = 4;
  static const int mod = 5;
  static const int eq = 6;
  static const int neq = 7;
  static const int lt = 8;
  static const int lte = 9;
  static const int gt = 10;
  static const int gte = 11;
}

enum _RegKind {
  unknown,
  emptyList,
  intT,
  doubleT,
  listIntT,
  listDoubleT,
  objT,
}

abstract final class _Bank {
  static const int i = 0;
  static const int f = 1;
  static const int o = 2;
  static const int il = 3;
  static const int fl = 4;
  static const int none = 5;
}

class _CallSite {
  const _CallSite({
    required this.srcBanks,
    required this.srcRegs,
    required this.dstBanks,
    required this.dstRegs,
    required this.retBank,
  });

  final Int32List srcBanks;
  final Int32List srcRegs;
  final Int32List dstBanks;
  final Int32List dstRegs;
  final int retBank;
}

class _GlobalExport {
  const _GlobalExport(this.globalSlot, this.bank, this.reg);
  final int globalSlot;
  final int bank;
  final int reg;
}

/// Compiled register-bytecode chunk for one function (or `<main>`).
class QudsBytecodeFunction {
  const QudsBytecodeFunction({
    required this.name,
    required this.arity,
    required this.iSize,
    required this.fSize,
    required this.oSize,
    required this.ilSize,
    required this.flSize,
    required this.paramBanks,
    required this.paramRegs,
    required this.returnBank,
    required this.code,
    required this.lines,
    required this.iConsts,
    required this.fConsts,
    required this.oConsts,
    required this.callSites,
    this.exports = const [],
    this.resultBank = _Bank.none,
    this.resultReg = 0,
  });

  final String name;
  final int arity;
  final int iSize;
  final int fSize;
  final int oSize;
  final int ilSize;
  final int flSize;
  final Int32List paramBanks;
  final Int32List paramRegs;
  final int returnBank;
  final Int32List code;
  final Int32List lines;
  final Int64List iConsts;
  final Float64List fConsts;
  final List<Object?> oConsts;
  final List<_CallSite> callSites;
  final List<_GlobalExport> exports;
  final int resultBank;
  final int resultReg;

  String disassemble() {
    final buf = StringBuffer(
      'fn $name(arity=$arity, i=$iSize, f=$fSize, il=$ilSize, fl=$flSize, o=$oSize):\n',
    );
    for (var ip = 0; ip < code.length; ip += 2) {
      final w0 = code[ip];
      final c = code[ip + 1];
      final op = w0 & 0xFF;
      final a = (w0 >> 8) & 0x3FF;
      final b = (w0 >> 18) & 0x3FF;
      final opName = op < QudsOp.names.length ? QudsOp.names[op] : 'OP_$op';
      final line = lines[ip >> 1];
      buf.writeln(
        '  ${ip.toString().padLeft(4, '0')} [L$line] '
        '${opName.padRight(20)} a=$a b=$b c=$c',
      );
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
    this.globalMutable = const {},
    this.functionDecls = const [],
  });

  final List<QudsBytecodeFunction> functions;
  final int mainIndex;
  final List<String> globalNames;
  final String file;
  final Map<String, bool> globalMutable;
  final List<FunctionDeclaration> functionDecls;

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

class _Val {
  const _Val(this.kind, this.reg, {this.isTemp = false});
  final _RegKind kind;
  final int reg;
  final bool isTemp;

  int get bank => switch (kind) {
        _RegKind.intT => _Bank.i,
        _RegKind.doubleT => _Bank.f,
        _RegKind.listIntT => _Bank.il,
        _RegKind.listDoubleT => _Bank.fl,
        _RegKind.objT || _RegKind.unknown || _RegKind.emptyList => _Bank.o,
      };
}

class _LoopPatch {
  _LoopPatch(this.continueTarget);
  int continueTarget;
  final List<int> breaks = [];
  final List<int> continues = [];
}

/// Compiles a pure-Quds [Program] AST into a typed 3-address register
/// [QudsBytecodeProgram]. Returns `null` when unsupported dynamic features
/// require the AST evaluator.
class QudsBytecodeCompiler {
  QudsBytecodeCompiler._(this._file);

  final String _file;
  final Map<String, int> _fnIndices = {};
  final Map<String, FunctionDeclaration> _fnDecls = {};
  final Map<String, List<_RegKind>> _fnParamKinds = {};
  final Map<String, _RegKind> _fnReturnKinds = {};
  final Map<String, int> _globalSlots = {};
  final List<String> _globalNames = [];
  final Set<String> _sharedGlobals = {};
  final Set<String> _mathPrefixes = {};

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

  /// Compiles the maximal subset of pure-compute functions from [allFns] into a
  /// Tier-1 unboxed register [QudsBytecodeProgram] so Universal VM scripts (such
  /// as `quds:viz` animations or multi-file projects) can execute hot numeric
  /// kernels at full 90M+ ops/sec speed.
  static QudsBytecodeProgram? tryCompilePureFunctions(
    List<FunctionDeclaration> allFns, {
    String file = '<bytecode>',
    Set<String> mathPrefixes = const {},
  }) {
    if (allFns.isEmpty) return null;
    final nameCounts = <String, int>{};
    for (final fn in allFns) {
      nameCounts[fn.name] = (nameCounts[fn.name] ?? 0) + 1;
    }
    final candidates = <FunctionDeclaration>[];
    for (final fn in allFns) {
      if ((nameCounts[fn.name] ?? 0) > 1)
        continue; // Overloads use Universal VM
      if (fn.isAsync ||
          fn.generator.isNotEmpty ||
          fn.typeParameters.isNotEmpty ||
          fn.parameters.any(
            (p) => p.isNamed || p.variadic || p.defaultValue != null,
          )) {
        continue;
      }
      candidates.add(fn);
    }
    if (candidates.isEmpty) return null;

    // First try compiling all candidates together (supports mutual calls).
    final synthetic = <Statement>[
      for (final p in mathPrefixes)
        ImportDeclaration('quds:math', p, candidates.first.span),
      if (mathPrefixes.isEmpty)
        ImportDeclaration('quds:math', null, candidates.first.span),
      ...candidates,
    ];
    final combined = tryCompile(
      Program(synthetic, candidates.first.span),
      file: file,
    );
    if (combined != null) return combined;

    // Otherwise greedily compile individual self-contained pure functions.
    final accepted = <FunctionDeclaration>[];
    for (final fn in candidates) {
      final probe = tryCompile(
        Program([
          for (final p in mathPrefixes)
            ImportDeclaration('quds:math', p, fn.span),
          if (mathPrefixes.isEmpty)
            ImportDeclaration('quds:math', null, fn.span),
          ...accepted,
          fn,
        ], fn.span),
        file: file,
      );
      if (probe != null) {
        accepted.add(fn);
      }
    }
    if (accepted.isEmpty) return null;
    return tryCompile(
      Program([
        for (final p in mathPrefixes)
          ImportDeclaration('quds:math', p, accepted.first.span),
        if (mathPrefixes.isEmpty)
          ImportDeclaration('quds:math', null, accepted.first.span),
        ...accepted,
      ], accepted.first.span),
      file: file,
    );
  }

  static QudsBytecodeProgram? tryCompileSource(
    String source, {
    String file = '<bytecode>',
  }) {
    final tokens = const Lexer().tokenize(source, file: file);
    final program = Parser(tokens).parse();
    return tryCompile(program, file: file);
  }

  int _ensureGlobal(String name) {
    final existing = _globalSlots[name];
    if (existing != null) return existing;
    final slot = _globalNames.length;
    _globalNames.add(name);
    _globalSlots[name] = slot;
    return slot;
  }

  /// Ensures Tier-1 never silently bypasses QUDS-090 immutability (`E202`),
  /// accidental shadowing (`E203`), or reactive/late/shadow bindings.
  static void _validateBindingSemantics(
    List<Statement> stmts,
    Map<String, bool> outerMutable,
  ) {
    final localMutable = <String, bool>{};
    for (final stmt in stmts) {
      switch (stmt) {
        case Binding():
          if (stmt.mode == BindingMode.shadow ||
              stmt.mode == BindingMode.shadowMutable ||
              stmt.mode == BindingMode.lateFinal ||
              stmt.mode == BindingMode.lateMutable ||
              stmt.mode == BindingMode.state ||
              stmt.mode == BindingMode.computed ||
              stmt.open) {
            throw const _UnsupportedBytecode();
          }
          final isExplicitDecl = stmt.mode == BindingMode.mutable ||
              stmt.mode == BindingMode.constant ||
              stmt.type != null;
          if (stmt.operator != '=') {
            final isMut = localMutable[stmt.name] ?? outerMutable[stmt.name];
            if (isMut != true) throw const _UnsupportedBytecode();
          } else if (isExplicitDecl) {
            if (localMutable.containsKey(stmt.name) ||
                outerMutable.containsKey(stmt.name)) {
              throw const _UnsupportedBytecode();
            }
            localMutable[stmt.name] = stmt.mode == BindingMode.mutable;
          } else {
            // Inferred `name = value`
            if (localMutable.containsKey(stmt.name)) {
              if (!localMutable[stmt.name]!) {
                throw const _UnsupportedBytecode();
              }
            } else if (outerMutable.containsKey(stmt.name)) {
              if (!outerMutable[stmt.name]!) {
                throw const _UnsupportedBytecode();
              }
            } else {
              localMutable[stmt.name] = false;
            }
          }
        case IfStatement(:final thenBody, :final elseBody):
          final merged = {...outerMutable, ...localMutable};
          _validateBindingSemantics(thenBody, merged);
          if (elseBody.isNotEmpty) _validateBindingSemantics(elseBody, merged);
        case WhileStatement(:final body, :final elseBody):
          final merged = {...outerMutable, ...localMutable};
          _validateBindingSemantics(body, merged);
          if (elseBody.isNotEmpty) _validateBindingSemantics(elseBody, merged);
        case ForStatement(
            :final name,
            :final index,
            :final body,
            :final elseBody
          ):
          final merged = {
            ...outerMutable,
            ...localMutable,
            name: false,
            if (index != null) index: false,
          };
          _validateBindingSemantics(body, merged);
          if (elseBody.isNotEmpty) _validateBindingSemantics(elseBody, merged);
        default:
          break;
      }
    }
  }

  QudsBytecodeProgram _compileProgram(Program program) {
    final topStmts = <Statement>[];
    final fnList = <FunctionDeclaration>[];

    for (final stmt in program.statements) {
      if (stmt is ImportDeclaration) {
        if (stmt.uri == 'dart:math' || stmt.uri == 'quds:math') {
          if (stmt.deferred || stmt.show.isNotEmpty || stmt.hide.isNotEmpty) {
            throw const _UnsupportedBytecode();
          }
          if (stmt.prefix != null) _mathPrefixes.add(stmt.prefix!);
          continue;
        }
        throw const _UnsupportedBytecode();
      }
      if (stmt is FunctionDeclaration) {
        if (stmt.isAsync ||
            stmt.generator.isNotEmpty ||
            stmt.typeParameters.isNotEmpty ||
            _fnIndices.containsKey(stmt.name) ||
            stmt.parameters.any(
              (p) => p.isNamed || p.variadic || p.defaultValue != null,
            )) {
          throw const _UnsupportedBytecode();
        }
        _fnIndices[stmt.name] = fnList.length;
        _fnDecls[stmt.name] = stmt;
        fnList.add(stmt);
      } else {
        topStmts.add(stmt);
      }
    }

    _validateBindingSemantics(topStmts, const {});
    for (final fn in fnList) {
      if (fn.body != null) {
        final params = {for (final p in fn.parameters) p.name: p.mutable};
        _validateBindingSemantics(fn.body!, params);
      }
    }

    final topLevelVars = <String>{};
    final globalMutable = <String, bool>{};
    for (final stmt in topStmts) {
      if (stmt is Binding) {
        topLevelVars.add(stmt.name);
        _ensureGlobal(stmt.name);
        globalMutable.putIfAbsent(
            stmt.name, () => stmt.mode == BindingMode.mutable);
      } else if (stmt is ForStatement) {
        topLevelVars.add(stmt.name);
        _ensureGlobal(stmt.name);
        globalMutable.putIfAbsent(stmt.name, () => false);
      }
    }

    for (final fn in fnList) {
      final paramAndLocal = <String>{for (final p in fn.parameters) p.name};
      if (fn.body != null) {
        _collectAssignedLocals(fn.body!, paramAndLocal);
        _collectExternalRefs(
            fn.body!, paramAndLocal, topLevelVars, _sharedGlobals);
      }
      if (fn.expressionBody != null) {
        _collectExprExternalRefs(
          fn.expressionBody!,
          paramAndLocal,
          topLevelVars,
          _sharedGlobals,
        );
      }
    }

    for (final fn in fnList) {
      _fnParamKinds[fn.name] = [
        for (final p in fn.parameters) _kindFromTypeName(p.type),
      ];
      _fnReturnKinds[fn.name] =
          (fn.returnType != null && fn.returnType!.isNotEmpty)
              ? _kindFromTypeName(fn.returnType)
              : _RegKind.unknown;
    }

    for (var pass = 0; pass < 4; pass++) {
      for (final fn in fnList) {
        if (fn.returnType != null && fn.returnType!.isNotEmpty) continue;
        final inferred = _inferFunctionReturnKind(fn);
        if (inferred != null && inferred != _RegKind.unknown) {
          _fnReturnKinds[fn.name] = inferred;
        }
      }
    }

    for (final fn in fnList) {
      final k = _fnReturnKinds[fn.name];
      if (k == null || k == _RegKind.unknown || k == _RegKind.emptyList) {
        _fnReturnKinds[fn.name] = _RegKind.objT;
      }
    }

    final compiledFns = <QudsBytecodeFunction>[];
    for (var i = 0; i < fnList.length; i++) {
      final fn = fnList[i];
      final fb = _RegFnCompiler(this, fn.name, isMain: false, selfFnIdx: i);
      compiledFns.add(fb.compileFunction(fn));
    }

    final mainIndex = compiledFns.length;
    final mainBuilder =
        _RegFnCompiler(this, '<main>', isMain: true, selfFnIdx: mainIndex);
    compiledFns.add(mainBuilder.compileMain(topStmts));

    return QudsBytecodeProgram(
      functions: compiledFns,
      mainIndex: mainIndex,
      globalNames: List.unmodifiable(_globalNames),
      file: _file,
      globalMutable: Map.unmodifiable(globalMutable),
      functionDecls: List.unmodifiable(fnList),
    );
  }

  static _RegKind _kindFromTypeName(String? typeName) {
    if (typeName == null || typeName.isEmpty || typeName.endsWith('?')) {
      return _RegKind.objT;
    }
    return switch (typeName) {
      'int' => _RegKind.intT,
      'double' => _RegKind.doubleT,
      _ => _RegKind.objT,
    };
  }

  _RegKind? _inferFunctionReturnKind(FunctionDeclaration fn) {
    final env = <String, _RegKind>{};
    final pKinds = _fnParamKinds[fn.name]!;
    for (var i = 0; i < fn.parameters.length; i++) {
      env[fn.parameters[i].name] = pKinds[i];
    }
    if (fn.expressionBody != null) {
      return _inferExprKind(fn.expressionBody!, env);
    }
    if (fn.body == null) return null;
    _inferStmtsEnv(fn.body!, env, isMain: false);
    var retKind = _RegKind.unknown;
    var sawReturn = false;
    void visit(List<Statement> stmts) {
      for (final s in stmts) {
        if (s is ReturnStatement) {
          sawReturn = true;
          final k =
              s.value == null ? _RegKind.objT : _inferExprKind(s.value!, env);
          retKind = _mergeKinds(retKind, k);
        } else if (s is IfStatement) {
          visit(s.thenBody);
          visit(s.elseBody);
        } else if (s is WhileStatement) {
          visit(s.body);
        } else if (s is ForStatement) {
          visit(s.body);
        } else if (s is RepeatStatement) {
          visit(s.body);
        }
      }
    }

    visit(fn.body!);
    return sawReturn ? retKind : _RegKind.objT;
  }

  /// Monotonic fixed-point local variable & typed-list kind inference.
  void _inferStmtsEnv(
    List<Statement> stmts,
    Map<String, _RegKind> env, {
    required bool isMain,
    Set<String>? outEmptyListCandidates,
  }) {
    final emptyListCandidates = <String>{};
    void findEmptyLists(List<Statement> list) {
      for (final s in list) {
        if (s is Binding &&
            s.operator == '=' &&
            s.value is ListExpression &&
            (s.value as ListExpression).elements.isEmpty) {
          if (!(isMain && _sharedGlobals.contains(s.name))) {
            emptyListCandidates.add(s.name);
          }
        } else if (s is IfStatement) {
          findEmptyLists(s.thenBody);
          findEmptyLists(s.elseBody);
        } else if (s is WhileStatement) {
          findEmptyLists(s.body);
        } else if (s is ForStatement) {
          findEmptyLists(s.body);
        } else if (s is RepeatStatement) {
          findEmptyLists(s.body);
        }
      }
    }

    findEmptyLists(stmts);
    if (outEmptyListCandidates != null) {
      outEmptyListCandidates.addAll(emptyListCandidates);
    }

    final listElemVotes = <String, _RegKind>{};
    final listInvalid = <String>{};

    void voteListElem(String vname, _RegKind elemK) {
      if (!emptyListCandidates.contains(vname) || listInvalid.contains(vname)) {
        return;
      }
      if (elemK == _RegKind.unknown) return;
      if (elemK != _RegKind.intT && elemK != _RegKind.doubleT) {
        listInvalid.add(vname);
        return;
      }
      final prev = listElemVotes[vname];
      if (prev == null) {
        listElemVotes[vname] = elemK;
      } else if (prev != elemK) {
        listInvalid.add(vname);
      }
    }

    for (var round = 0; round < 4; round++) {
      void walk(List<Statement> list) {
        for (final s in list) {
          if (s is Binding) {
            if (isMain && _sharedGlobals.contains(s.name)) continue;
            if (emptyListCandidates.contains(s.name) &&
                s.operator == '=' &&
                s.value is ListExpression &&
                (s.value as ListExpression).elements.isEmpty) {
              if (listInvalid.contains(s.name)) {
                env[s.name] = _RegKind.objT;
              } else {
                final v = listElemVotes[s.name];
                if (v == _RegKind.intT) {
                  env[s.name] = _RegKind.listIntT;
                } else if (v == _RegKind.doubleT) {
                  env[s.name] = _RegKind.listDoubleT;
                } else {
                  env.putIfAbsent(s.name, () => _RegKind.emptyList);
                }
              }
              continue;
            }
            if (emptyListCandidates.contains(s.name) && s.operator == '=') {
              // Variable reassigned to a non-empty-list expression; invalidate
              // unboxed empty-list candidate unless it matches.
              final rhsK = _inferExprKind(s.value, env);
              if (rhsK != _RegKind.unknown &&
                  rhsK != _RegKind.emptyList &&
                  rhsK != env[s.name]) {
                listInvalid.add(s.name);
              }
            }
            final k = s.operator == '/='
                ? _RegKind.doubleT
                : (s.type != null && s.type!.isNotEmpty
                    ? _kindFromTypeName(s.type)
                    : _inferExprKind(s.value, env));
            final prev = env[s.name] ?? _RegKind.unknown;
            env[s.name] = _mergeKinds(prev, k);
          } else if (s is IndexAssignment) {
            if (s.target.object is Identifier) {
              final lname = (s.target.object as Identifier).name;
              final valK = _inferExprKind(s.value, env);
              voteListElem(lname, valK);
            }
          } else if (s is ExpressionStatement) {
            final e = s.expression;
            if (e is CallExpression &&
                e.callee is MemberAccess &&
                (e.callee as MemberAccess).name == 'add' &&
                e.arguments.length == 1) {
              final target = (e.callee as MemberAccess).object;
              if (target is Identifier) {
                final valK = _inferExprKind(e.arguments.first.value, env);
                voteListElem(target.name, valK);
              }
            }
          } else if (s is ForStatement) {
            env[s.name] = _RegKind.intT;
            walk(s.body);
          } else if (s is IfStatement) {
            walk(s.thenBody);
            walk(s.elseBody);
          } else if (s is WhileStatement) {
            walk(s.body);
          } else if (s is RepeatStatement) {
            walk(s.body);
          }
        }
      }

      walk(stmts);
      for (final cand in emptyListCandidates) {
        if (listInvalid.contains(cand)) {
          env[cand] = _RegKind.objT;
        } else if (listElemVotes[cand] == _RegKind.intT) {
          env[cand] = _RegKind.listIntT;
        } else if (listElemVotes[cand] == _RegKind.doubleT) {
          env[cand] = _RegKind.listDoubleT;
        }
      }
    }

    for (final key in env.keys.toList()) {
      final k = env[key];
      if (k == _RegKind.unknown || k == _RegKind.emptyList) {
        env[key] = _RegKind.objT;
      }
    }
  }

  static _RegKind _mergeKinds(_RegKind a, _RegKind b) {
    if (a == b) return a;
    if (a == _RegKind.unknown) return b;
    if (b == _RegKind.unknown) return a;
    if (a == _RegKind.emptyList &&
        (b == _RegKind.listIntT || b == _RegKind.listDoubleT)) {
      return b;
    }
    if (b == _RegKind.emptyList &&
        (a == _RegKind.listIntT || a == _RegKind.listDoubleT)) {
      return a;
    }
    if ((a == _RegKind.intT && b == _RegKind.doubleT) ||
        (a == _RegKind.doubleT && b == _RegKind.intT)) {
      return _RegKind.doubleT;
    }
    return _RegKind.objT;
  }

  _RegKind _inferExprKind(Expression expr, Map<String, _RegKind> env) {
    if (expr is Literal) {
      if (expr.value is int) return _RegKind.intT;
      if (expr.value is double) return _RegKind.doubleT;
      return _RegKind.objT;
    }
    if (expr is Identifier) {
      if (expr.name == 'pi' || expr.name == 'e') return _RegKind.doubleT;
      if (_sharedGlobals.contains(expr.name)) return _RegKind.objT;
      final local = env[expr.name];
      if (local != null) return local;
      if (_globalSlots.containsKey(expr.name)) return _RegKind.objT;
      return _RegKind.unknown;
    }
    if (expr is UnaryExpression) {
      if (expr.operator == '-') return _inferExprKind(expr.operand, env);
      return _RegKind.objT;
    }
    if (expr is BinaryExpression) {
      if (expr.operator == '/') {
        final l = _inferExprKind(expr.left, env);
        final r = _inferExprKind(expr.right, env);
        if (l == _RegKind.unknown || r == _RegKind.unknown) {
          return _RegKind.unknown;
        }
        if (_isNumKind(l) && _isNumKind(r)) return _RegKind.doubleT;
        return _RegKind.objT;
      }
      if (expr.operator == '~/') return _RegKind.intT;
      if (const {'+', '-', '*', '%'}.contains(expr.operator)) {
        final l = _inferExprKind(expr.left, env);
        final r = _inferExprKind(expr.right, env);
        if (l == _RegKind.objT ||
            r == _RegKind.objT ||
            l == _RegKind.listIntT ||
            l == _RegKind.listDoubleT ||
            l == _RegKind.emptyList ||
            r == _RegKind.listIntT ||
            r == _RegKind.listDoubleT ||
            r == _RegKind.emptyList) {
          return _RegKind.objT;
        }
        if (l == _RegKind.unknown || r == _RegKind.unknown) {
          return _RegKind.unknown;
        }
        if (l == _RegKind.intT && r == _RegKind.intT) return _RegKind.intT;
        if (_isNumKind(l) && _isNumKind(r)) return _RegKind.doubleT;
        return _RegKind.objT;
      }
      return _RegKind.objT;
    }
    if (expr is MemberAccess) {
      if (expr.object is Identifier &&
          _mathPrefixes.contains((expr.object as Identifier).name)) {
        if (const {'pi', 'e', 'ln2', 'ln10', 'sqrt2'}.contains(expr.name)) {
          return _RegKind.doubleT;
        }
      }
      if (expr.name == 'length') return _RegKind.intT;
      return _RegKind.objT;
    }
    if (expr is IndexExpression) {
      final tk = _inferExprKind(expr.object, env);
      if (tk == _RegKind.unknown || tk == _RegKind.emptyList) {
        return _RegKind.unknown;
      }
      if (tk == _RegKind.listIntT) return _RegKind.intT;
      if (tk == _RegKind.listDoubleT) return _RegKind.doubleT;
      return _RegKind.objT;
    }
    if (expr is CallExpression) {
      if (expr.callee is Identifier) {
        final name = (expr.callee as Identifier).name;
        if (_fnReturnKinds.containsKey(name)) return _fnReturnKinds[name]!;
        if (const {
          'sin',
          'cos',
          'tan',
          'sqrt',
          'abs',
          'exp',
          'log',
          'pow',
          'min',
          'max',
          'double',
          'toDouble',
        }.contains(name)) {
          return _RegKind.doubleT;
        }
        if (name == 'int' || name == 'toInt') return _RegKind.intT;
      }
      if (expr.callee is MemberAccess) {
        final mem = expr.callee as MemberAccess;
        if (mem.object is Identifier &&
            _mathPrefixes.contains((mem.object as Identifier).name)) {
          if (const {
            'sin',
            'cos',
            'tan',
            'sqrt',
            'abs',
            'exp',
            'log',
            'pow',
            'min',
            'max',
          }.contains(mem.name)) {
            return _RegKind.doubleT;
          }
        }
      }
      return _RegKind.objT;
    }
    if (expr is ListExpression) {
      if (expr.elements.isEmpty) return _RegKind.emptyList;
      var k = _inferExprKind(expr.elements.first, env);
      for (var i = 1; i < expr.elements.length; i++) {
        k = _mergeKinds(k, _inferExprKind(expr.elements[i], env));
      }
      if (k == _RegKind.unknown) return _RegKind.emptyList;
      if (k == _RegKind.intT) return _RegKind.listIntT;
      if (k == _RegKind.doubleT) return _RegKind.listDoubleT;
      return _RegKind.objT;
    }
    return _RegKind.objT;
  }

  static bool _isNumKind(_RegKind k) =>
      k == _RegKind.intT || k == _RegKind.doubleT;

  void _collectAssignedLocals(List<Statement> stmts, Set<String> locals) {
    for (final s in stmts) {
      if (s is Binding) {
        locals.add(s.name);
      } else if (s is ForStatement) {
        locals.add(s.name);
        _collectAssignedLocals(s.body, locals);
      } else if (s is IfStatement) {
        _collectAssignedLocals(s.thenBody, locals);
        _collectAssignedLocals(s.elseBody, locals);
      } else if (s is WhileStatement) {
        _collectAssignedLocals(s.body, locals);
      } else if (s is RepeatStatement) {
        _collectAssignedLocals(s.body, locals);
      }
    }
  }

  void _collectExternalRefs(
    List<Statement> stmts,
    Set<String> locals,
    Set<String> globals,
    Set<String> out,
  ) {
    for (final s in stmts) {
      if (s is Binding) {
        _collectExprExternalRefs(s.value, locals, globals, out);
      } else if (s is IndexAssignment) {
        _collectExprExternalRefs(s.target.object, locals, globals, out);
        _collectExprExternalRefs(s.target.index, locals, globals, out);
        _collectExprExternalRefs(s.value, locals, globals, out);
      } else if (s is ReturnStatement && s.value != null) {
        _collectExprExternalRefs(s.value!, locals, globals, out);
      } else if (s is ExpressionStatement) {
        _collectExprExternalRefs(s.expression, locals, globals, out);
      } else if (s is IfStatement) {
        _collectExprExternalRefs(s.condition, locals, globals, out);
        _collectExternalRefs(s.thenBody, locals, globals, out);
        _collectExternalRefs(s.elseBody, locals, globals, out);
      } else if (s is WhileStatement) {
        _collectExprExternalRefs(s.condition, locals, globals, out);
        _collectExternalRefs(s.body, locals, globals, out);
      } else if (s is ForStatement) {
        _collectExprExternalRefs(s.iterable, locals, globals, out);
        if (s.step != null) {
          _collectExprExternalRefs(s.step!, locals, globals, out);
        }
        _collectExternalRefs(s.body, locals, globals, out);
      } else if (s is RepeatStatement) {
        if (s.count != null) {
          _collectExprExternalRefs(s.count!, locals, globals, out);
        }
        _collectExternalRefs(s.body, locals, globals, out);
      }
    }
  }

  void _collectExprExternalRefs(
    Expression expr,
    Set<String> locals,
    Set<String> globals,
    Set<String> out,
  ) {
    if (expr is Identifier) {
      if (!locals.contains(expr.name) && globals.contains(expr.name)) {
        out.add(expr.name);
      }
    } else if (expr is UnaryExpression) {
      _collectExprExternalRefs(expr.operand, locals, globals, out);
    } else if (expr is BinaryExpression) {
      _collectExprExternalRefs(expr.left, locals, globals, out);
      _collectExprExternalRefs(expr.right, locals, globals, out);
    } else if (expr is CallExpression) {
      _collectExprExternalRefs(expr.callee, locals, globals, out);
      for (final a in expr.arguments) {
        _collectExprExternalRefs(a.value, locals, globals, out);
      }
    } else if (expr is MemberAccess) {
      _collectExprExternalRefs(expr.object, locals, globals, out);
    } else if (expr is IndexExpression) {
      _collectExprExternalRefs(expr.object, locals, globals, out);
      _collectExprExternalRefs(expr.index, locals, globals, out);
    } else if (expr is ListExpression) {
      for (final e in expr.elements) {
        _collectExprExternalRefs(e, locals, globals, out);
      }
    } else if (expr is InterpolatedString) {
      for (final p in expr.parts) {
        _collectExprExternalRefs(p, locals, globals, out);
      }
    } else if (expr is RangeExpression) {
      _collectExprExternalRefs(expr.start, locals, globals, out);
      _collectExprExternalRefs(expr.end, locals, globals, out);
    }
  }
}

class _RegFnCompiler {
  _RegFnCompiler(
    this.compiler,
    this.name, {
    required this.isMain,
    required this.selfFnIdx,
  });

  final QudsBytecodeCompiler compiler;
  final String name;
  final bool isMain;
  final int selfFnIdx;

  final List<int> _code = [];
  final List<int> _lines = [];
  final List<int> _iConsts = [];
  final Map<int, int> _iConstMap = {};
  final List<double> _fConsts = [];
  final Map<double, int> _fConstMap = {};
  final List<Object?> _oConsts = [];
  final List<_CallSite> _callSites = [];
  final List<_LoopPatch> _loopStack = [];

  final Map<String, _RegKind> _varKinds = {};
  final Map<String, int> _varRegs = {};
  final Set<String> _emptyListCandidates = {};

  /// Hoisted read-only constant registers (populated in prologue for functions
  /// containing loops so hot loops never re-load numeric literals!).
  final Map<int, int> _hoistedIRegs = {};
  final Map<double, int> _hoistedFRegs = {};

  /// Local basic-block Common Subexpression Elimination (CSE) caches for pure
  /// float/int binary operations. Automatically invalidated whenever an operand
  /// or destination register is written, reclaimed, or across control-flow merges.
  final Map<(int, int, int), int> _cseF = {};
  final Map<(int, int, int), int> _cseI = {};

  /// Patch list for `CALL_FN_SELF_I1_SUB` instructions whose final `iSize` is
  /// patched once function compilation completes.
  final List<(int ip, int delta)> _selfCallPatches = [];
  final List<int> _selfRetPatches = [];
  bool _isPureIntSelfRec = false;

  int _iNext = 0;
  int _fNext = 0;
  int _oNext = 0;
  int _ilNext = 0;
  int _flNext = 0;
  int _iMax = 0;
  int _fMax = 0;
  int _oMax = 0;
  int _ilMax = 0;
  int _flMax = 0;

  void _clearCse() {
    _cseF.clear();
    _cseI.clear();
  }

  void _invalidateF(int reg) {
    if (_cseF.isEmpty) return;
    _cseF.removeWhere((k, v) => v == reg || k.$2 == reg || k.$3 == reg);
  }

  void _invalidateI(int reg) {
    if (_cseI.isEmpty) return;
    _cseI.removeWhere((k, v) => v == reg || k.$2 == reg || k.$3 == reg);
  }

  void _pruneCseTemps() {
    if (_cseF.isNotEmpty) {
      _cseF.removeWhere(
        (k, v) => v >= _fNext || k.$2 >= _fNext || k.$3 >= _fNext,
      );
    }
    if (_cseI.isNotEmpty) {
      _cseI.removeWhere(
        (k, v) => v >= _iNext || k.$2 >= _iNext || k.$3 >= _iNext,
      );
    }
  }

  (int, int, int) _cseKey(int op, int r1, int r2) {
    final commutative = op == QudsOp.fAdd ||
        op == QudsOp.fMul ||
        op == QudsOp.iAdd ||
        op == QudsOp.iMul;
    if (commutative && r1 > r2) return (op, r2, r1);
    return (op, r1, r2);
  }

  int _allocI() {
    final r = _iNext++;
    if (_iNext > _iMax) _iMax = _iNext;
    if (r >= 1020) throw const _UnsupportedBytecode();
    return r;
  }

  int _allocF() {
    final r = _fNext++;
    if (_fNext > _fMax) _fMax = _fNext;
    if (r >= 1020) throw const _UnsupportedBytecode();
    return r;
  }

  int _allocO() {
    final r = _oNext++;
    if (_oNext > _oMax) _oMax = _oNext;
    if (r >= 1020) throw const _UnsupportedBytecode();
    return r;
  }

  int _allocIL() {
    final r = _ilNext++;
    if (_ilNext > _ilMax) _ilMax = _ilNext;
    if (r >= 1020) throw const _UnsupportedBytecode();
    return r;
  }

  int _allocFL() {
    final r = _flNext++;
    if (_flNext > _flMax) _flMax = _flNext;
    if (r >= 1020) throw const _UnsupportedBytecode();
    return r;
  }

  int _allocFor(_RegKind kind) => switch (kind) {
        _RegKind.intT => _allocI(),
        _RegKind.doubleT => _allocF(),
        _RegKind.listIntT => _allocIL(),
        _RegKind.listDoubleT => _allocFL(),
        _RegKind.objT || _RegKind.unknown || _RegKind.emptyList => _allocO(),
      };

  int _addIConst(int v) {
    final idx = _iConstMap[v];
    if (idx != null) return idx;
    final n = _iConsts.length;
    _iConsts.add(v);
    _iConstMap[v] = n;
    return n;
  }

  int _addFConst(double v) {
    final idx = _fConstMap[v];
    if (idx != null) return idx;
    final n = _fConsts.length;
    _fConsts.add(v);
    _fConstMap[v] = n;
    return n;
  }

  int _addOConst(Object? v) {
    for (var i = 0; i < _oConsts.length; i++) {
      if (identical(_oConsts[i], v) ||
          (_oConsts[i].runtimeType == v.runtimeType && _oConsts[i] == v)) {
        return i;
      }
    }
    _oConsts.add(v);
    return _oConsts.length - 1;
  }

  int _emit(int op, int a, int b, int c, int line) {
    final ip = _code.length;
    _code.add((op & 0xFF) | ((a & 0x3FF) << 8) | ((b & 0x3FF) << 18));
    _code.add(c);
    _lines.add(line);
    // Keep CSE caches sound whenever any register is modified or control transfers.
    switch (op) {
      case QudsOp.fLoadK:
      case QudsOp.fMove:
      case QudsOp.fAdd:
      case QudsOp.fSub:
      case QudsOp.fMul:
      case QudsOp.fDiv:
      case QudsOp.fNeg:
      case QudsOp.fMulAdd:
      case QudsOp.fSqrt:
      case QudsOp.fIntrinsic:
      case QudsOp.fIntrinsic2:
      case QudsOp.iToF:
      case QudsOp.iDivF:
      case QudsOp.floatListGet:
      case QudsOp.oToF:
        _invalidateF(a);
      case QudsOp.iLoadK:
      case QudsOp.iLoadImm:
      case QudsOp.iMove:
      case QudsOp.iAdd:
      case QudsOp.iAddImm:
      case QudsOp.iSub:
      case QudsOp.iMul:
      case QudsOp.iIdiv:
      case QudsOp.iMod:
      case QudsOp.iNeg:
      case QudsOp.fToI:
      case QudsOp.intListGet:
      case QudsOp.iAddListGet:
      case QudsOp.intListLen:
      case QudsOp.floatListLen:
      case QudsOp.objListLen:
      case QudsOp.oToI:
        _invalidateI(a);
      case QudsOp.jump:
      case QudsOp.iIncJump:
      case QudsOp.iAddJump:
      case QudsOp.iIncJlt:
      case QudsOp.iIncJle:
      case QudsOp.callFn:
      case QudsOp.callFnI1:
      case QudsOp.callSelfI1Sub:
      case QudsOp.retI:
      case QudsOp.retF:
      case QudsOp.retO:
      case QudsOp.retVoid:
      case QudsOp.retSelfI:
        _clearCse();
      default:
        break;
    }
    return ip;
  }

  void _patchC(int ip, int c) {
    _code[ip + 1] = c;
  }

  bool _containsLoop(List<Statement> stmts) {
    for (final s in stmts) {
      if (s is WhileStatement || s is ForStatement || s is RepeatStatement) {
        return true;
      }
      if (s is IfStatement) {
        if (_containsLoop(s.thenBody) || _containsLoop(s.elseBody)) return true;
      }
    }
    return false;
  }

  /// Collects numeric literals used inside loops and pre-loads up to 24 of them
  /// into permanent read-only registers in the function prologue.
  void _hoistLoopConstants(List<Statement> stmts, int line) {
    if (!_containsLoop(stmts)) return;
    final iLits = <int>{};
    final fLits = <double>{};

    void scanExpr(Expression e) {
      if (e is Literal) {
        if (e.value is int && iLits.length < 16) iLits.add(e.value as int);
        if (e.value is double && fLits.length < 24) {
          fLits.add(e.value as double);
        }
      } else if (e is UnaryExpression) {
        scanExpr(e.operand);
      } else if (e is BinaryExpression) {
        scanExpr(e.left);
        scanExpr(e.right);
      } else if (e is CallExpression) {
        scanExpr(e.callee);
        for (final a in e.arguments) {
          scanExpr(a.value);
        }
      } else if (e is IndexExpression) {
        scanExpr(e.object);
        scanExpr(e.index);
      } else if (e is MemberAccess) {
        scanExpr(e.object);
      }
    }

    void scanStmts(List<Statement> list, bool inLoop) {
      for (final s in list) {
        if (s is WhileStatement) {
          scanExpr(s.condition);
          scanStmts(s.body, true);
        } else if (s is ForStatement) {
          scanStmts(s.body, true);
        } else if (s is RepeatStatement) {
          scanStmts(s.body, true);
        } else if (s is IfStatement) {
          if (inLoop) scanExpr(s.condition);
          scanStmts(s.thenBody, inLoop);
          scanStmts(s.elseBody, inLoop);
        } else if (inLoop) {
          if (s is Binding) {
            scanExpr(s.value);
          } else if (s is IndexAssignment) {
            scanExpr(s.target.index);
            scanExpr(s.value);
          } else if (s is ExpressionStatement) {
            scanExpr(s.expression);
          } else if (s is ReturnStatement && s.value != null) {
            scanExpr(s.value!);
          }
        }
      }
    }

    scanStmts(stmts, false);

    for (final v in iLits) {
      final reg = _allocI();
      _hoistedIRegs[v] = reg;
      if (v >= -2147483648 && v <= 2147483647) {
        _emit(QudsOp.iLoadImm, reg, 0, v, line);
      } else {
        _emit(QudsOp.iLoadK, reg, 0, _addIConst(v), line);
      }
    }
    for (final v in fLits) {
      final reg = _allocF();
      _hoistedFRegs[v] = reg;
      _emit(QudsOp.fLoadK, reg, 0, _addFConst(v), line);
    }
  }

  void _inferAllLocals(List<Statement> stmts) {
    compiler._inferStmtsEnv(
      stmts,
      _varKinds,
      isMain: isMain,
      outEmptyListCandidates: _emptyListCandidates,
    );

    for (final entry in _varKinds.entries) {
      if (!_varRegs.containsKey(entry.key)) {
        _varRegs[entry.key] = _allocFor(entry.value);
      }
    }
  }

  QudsBytecodeFunction compileFunction(FunctionDeclaration fn) {
    final paramKinds = compiler._fnParamKinds[fn.name]!;
    final paramBanks = Int32List(fn.parameters.length);
    final paramRegs = Int32List(fn.parameters.length);

    for (var i = 0; i < fn.parameters.length; i++) {
      final pName = fn.parameters[i].name;
      final pk = paramKinds[i];
      _varKinds[pName] = pk;
      final reg = _allocFor(pk);
      _varRegs[pName] = reg;
      paramBanks[i] = _bankFor(pk);
      paramRegs[i] = reg;
    }

    if (fn.body != null) {
      _inferAllLocals(fn.body!);
      _hoistLoopConstants(fn.body!, fn.span.line);
    }

    final retKind = compiler._fnReturnKinds[fn.name] ?? _RegKind.objT;
    final retBank = _bankFor(retKind);

    // Detect pure 1-int-arg self-recursive function (`fSize==0, oSize==0, ...`)
    _isPureIntSelfRec = fn.parameters.length == 1 &&
        paramKinds[0] == _RegKind.intT &&
        retKind == _RegKind.intT &&
        _fMax == 0 &&
        _oMax == 0 &&
        _ilMax == 0 &&
        _flMax == 0 &&
        fn.body != null &&
        !_containsLoop(fn.body!);

    if (fn.expressionBody != null) {
      final v = _compileExpr(fn.expressionBody!, desired: retKind);
      _emitReturn(v, retKind, fn.span.line);
    } else if (fn.body != null) {
      for (final stmt in fn.body!) {
        _compileStmt(stmt, expectedReturnKind: retKind);
      }
      _emit(QudsOp.retVoid, 0, 0, 0, fn.span.line);
    } else {
      throw const _UnsupportedBytecode();
    }

    // If function ended up using non-int registers, downgrade self-rec ops cleanly
    if (_fMax > 0 || _oMax > 0 || _ilMax > 0 || _flMax > 0) {
      if (_selfCallPatches.isNotEmpty || _selfRetPatches.isNotEmpty) {
        // Recompile safely without pure-int self-rec specialization
        final fallback = _RegFnCompiler(
          compiler,
          name,
          isMain: false,
          selfFnIdx: -1,
        );
        return fallback.compileFunction(fn);
      }
    } else {
      // Patch final `iSize` into all `callSelfI1Sub` and `retSelfI` instructions!
      for (final (ip, delta) in _selfCallPatches) {
        _patchC(ip, (delta << 10) | (_iMax & 0x3FF));
      }
      for (final ip in _selfRetPatches) {
        _patchC(ip, _iMax);
      }
    }

    return QudsBytecodeFunction(
      name: name,
      arity: fn.parameters.length,
      iSize: _iMax,
      fSize: _fMax,
      oSize: _oMax,
      ilSize: _ilMax,
      flSize: _flMax,
      paramBanks: paramBanks,
      paramRegs: paramRegs,
      returnBank: retBank,
      code: Int32List.fromList(_code),
      lines: Int32List.fromList(_lines),
      iConsts: Int64List.fromList(_iConsts),
      fConsts: Float64List.fromList(_fConsts),
      oConsts: List<Object?>.unmodifiable(_oConsts),
      callSites: List<_CallSite>.unmodifiable(_callSites),
    );
  }

  QudsBytecodeFunction compileMain(List<Statement> stmts) {
    _inferAllLocals(stmts);
    _hoistLoopConstants(stmts, stmts.isEmpty ? 1 : stmts.first.span.line);
    var resBank = _Bank.none;
    var resReg = 0;

    for (var i = 0; i < stmts.length; i++) {
      final stmt = stmts[i];
      final isLast = i == stmts.length - 1;
      if (isLast && stmt is ExpressionStatement) {
        final v = _compileExpr(stmt.expression);
        resBank = v.bank;
        resReg = v.reg;
      } else {
        _compileStmt(stmt);
      }
    }

    final exports = <_GlobalExport>[];
    for (final entry in compiler._globalSlots.entries) {
      if (compiler._sharedGlobals.contains(entry.key)) continue;
      final reg = _varRegs[entry.key];
      final kind = _varKinds[entry.key];
      if (reg != null && kind != null) {
        exports.add(_GlobalExport(entry.value, _bankFor(kind), reg));
      }
    }

    _emit(QudsOp.halt, 0, 0, 0, stmts.isEmpty ? 1 : stmts.last.span.line);

    return QudsBytecodeFunction(
      name: '<main>',
      arity: 0,
      iSize: _iMax,
      fSize: _fMax,
      oSize: _oMax,
      ilSize: _ilMax,
      flSize: _flMax,
      paramBanks: Int32List(0),
      paramRegs: Int32List(0),
      returnBank: _Bank.o,
      code: Int32List.fromList(_code),
      lines: Int32List.fromList(_lines),
      iConsts: Int64List.fromList(_iConsts),
      fConsts: Float64List.fromList(_fConsts),
      oConsts: List<Object?>.unmodifiable(_oConsts),
      callSites: List<_CallSite>.unmodifiable(_callSites),
      exports: exports,
      resultBank: resBank,
      resultReg: resReg,
    );
  }

  static int _bankFor(_RegKind k) => switch (k) {
        _RegKind.intT => _Bank.i,
        _RegKind.doubleT => _Bank.f,
        _RegKind.listIntT => _Bank.il,
        _RegKind.listDoubleT => _Bank.fl,
        _RegKind.objT || _RegKind.unknown || _RegKind.emptyList => _Bank.o,
      };

  /// Tries to fuse a trailing loop-counter update (`i = i + 1`, `m = m + p`,
  /// `i += 1`) together with the backward loop `jump` into a single
  /// `I_INC_JUMP` or `I_ADD_JUMP` superinstruction.
  bool _tryEmitFusedWhileLatch(Statement stmt, int loopStart) {
    if (stmt is! Binding) return false;
    if (stmt.mode == BindingMode.lateFinal ||
        stmt.mode == BindingMode.lateMutable) {
      return false;
    }
    if (isMain && compiler._sharedGlobals.contains(stmt.name)) return false;
    if (_varKinds[stmt.name] != _RegKind.intT) return false;
    final dstReg = _varRegs[stmt.name];
    if (dstReg == null) return false;
    final line = stmt.span.line;

    if (stmt.operator == '=' && stmt.value is BinaryExpression) {
      final bin = stmt.value as BinaryExpression;
      if ((bin.operator == '+' || bin.operator == '-') &&
          bin.left is Identifier &&
          (bin.left as Identifier).name == stmt.name) {
        if (bin.right is Literal && (bin.right as Literal).value is int) {
          final v = (bin.right as Literal).value as int;
          final delta = bin.operator == '+' ? v : -v;
          if (delta >= -512 && delta <= 511) {
            _emit(QudsOp.iIncJump, dstReg, delta + 512, loopStart, line);
            return true;
          }
        }
        if (bin.operator == '+' && bin.right is Identifier) {
          final rname = (bin.right as Identifier).name;
          if (!(isMain && compiler._sharedGlobals.contains(rname)) &&
              _varKinds[rname] == _RegKind.intT) {
            final stepReg = _varRegs[rname];
            if (stepReg != null) {
              _emit(QudsOp.iAddJump, dstReg, stepReg, loopStart, line);
              return true;
            }
          }
        }
      }
    } else if (stmt.operator == '+=' || stmt.operator == '-=') {
      if (stmt.value is Literal && (stmt.value as Literal).value is int) {
        final v = (stmt.value as Literal).value as int;
        final delta = stmt.operator == '+=' ? v : -v;
        if (delta >= -512 && delta <= 511) {
          _emit(QudsOp.iIncJump, dstReg, delta + 512, loopStart, line);
          return true;
        }
      }
      if (stmt.operator == '+=' && stmt.value is Identifier) {
        final rname = (stmt.value as Identifier).name;
        if (!(isMain && compiler._sharedGlobals.contains(rname)) &&
            _varKinds[rname] == _RegKind.intT) {
          final stepReg = _varRegs[rname];
          if (stepReg != null) {
            _emit(QudsOp.iAddJump, dstReg, stepReg, loopStart, line);
            return true;
          }
        }
      }
    }
    return false;
  }

  void _emitReturn(_Val v, _RegKind retKind, int line) {
    final coerced = _coerce(v, retKind, line);
    switch (retKind) {
      case _RegKind.intT:
        if (_isPureIntSelfRec && selfFnIdx >= 0) {
          final ip = _emit(QudsOp.retSelfI, coerced.reg, 0, 0, line);
          _selfRetPatches.add(ip);
        } else {
          _emit(QudsOp.retI, coerced.reg, 0, 0, line);
        }
      case _RegKind.doubleT:
        _emit(QudsOp.retF, coerced.reg, 0, 0, line);
      default:
        final o = _coerce(coerced, _RegKind.objT, line);
        _emit(QudsOp.retO, o.reg, 0, 0, line);
    }
  }

  _Val _coerce(_Val v, _RegKind target, int line) {
    if (v.kind == target) return v;
    if (target == _RegKind.objT && v.kind == _RegKind.listIntT) {
      final dst = _allocO();
      _emit(QudsOp.intListToO, dst, v.reg, 0, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }
    if (target == _RegKind.objT && v.kind == _RegKind.listDoubleT) {
      final dst = _allocO();
      _emit(QudsOp.floatListToO, dst, v.reg, 0, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }
    if (target == _RegKind.doubleT && v.kind == _RegKind.intT) {
      final dst = _allocF();
      _emit(QudsOp.iToF, dst, v.reg, 0, line);
      return _Val(_RegKind.doubleT, dst, isTemp: true);
    }
    if (target == _RegKind.intT && v.kind == _RegKind.doubleT) {
      final dst = _allocI();
      _emit(QudsOp.fToI, dst, v.reg, 0, line);
      return _Val(_RegKind.intT, dst, isTemp: true);
    }
    if (target == _RegKind.objT && v.kind == _RegKind.intT) {
      final dst = _allocO();
      _emit(QudsOp.iToO, dst, v.reg, 0, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }
    if (target == _RegKind.objT && v.kind == _RegKind.doubleT) {
      final dst = _allocO();
      _emit(QudsOp.fToO, dst, v.reg, 0, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }
    if (target == _RegKind.intT && v.kind == _RegKind.objT) {
      final dst = _allocI();
      _emit(QudsOp.oToI, dst, v.reg, 0, line);
      return _Val(_RegKind.intT, dst, isTemp: true);
    }
    if (target == _RegKind.doubleT && v.kind == _RegKind.objT) {
      final dst = _allocF();
      _emit(QudsOp.oToF, dst, v.reg, 0, line);
      return _Val(_RegKind.doubleT, dst, isTemp: true);
    }
    return v;
  }

  void _compileStmt(Statement stmt, {_RegKind? expectedReturnKind}) {
    final savedI = _iNext;
    final savedF = _fNext;
    final savedO = _oNext;
    final savedIL = _ilNext;
    final savedFL = _flNext;
    final line = stmt.span.line;

    void restoreTemps() {
      _iNext = savedI;
      _fNext = savedF;
      _oNext = savedO;
      _ilNext = savedIL;
      _flNext = savedFL;
      _pruneCseTemps();
    }

    if (stmt is Binding) {
      if (stmt.mode == BindingMode.lateFinal ||
          stmt.mode == BindingMode.lateMutable) {
        throw const _UnsupportedBytecode();
      }
      if (isMain && compiler._sharedGlobals.contains(stmt.name)) {
        final slot = compiler._ensureGlobal(stmt.name);
        if (stmt.operator == '=') {
          final v = _coerce(_compileExpr(stmt.value), _RegKind.objT, line);
          _emit(QudsOp.oStoreGlobal, v.reg, 0, slot, line);
        } else {
          final cur = _allocO();
          _emit(QudsOp.oLoadGlobal, cur, 0, slot, line);
          final rhs = _coerce(_compileExpr(stmt.value), _RegKind.objT, line);
          _emit(
            QudsOp.oBinOp,
            cur,
            cur,
            (rhs.reg << 8) | _dynCompoundOp(stmt.operator),
            line,
          );
          _emit(QudsOp.oStoreGlobal, cur, 0, slot, line);
        }
        restoreTemps();
        return;
      }

      final reg = _varRegs[stmt.name];
      final kind = _varKinds[stmt.name];
      if (reg == null || kind == null) {
        final slot = compiler._globalSlots[stmt.name];
        if (slot == null) throw const _UnsupportedBytecode();
        if (stmt.operator == '=') {
          final v = _coerce(_compileExpr(stmt.value), _RegKind.objT, line);
          _emit(QudsOp.oStoreGlobal, v.reg, 0, slot, line);
        } else {
          final cur = _allocO();
          _emit(QudsOp.oLoadGlobal, cur, 0, slot, line);
          final rhs = _coerce(_compileExpr(stmt.value), _RegKind.objT, line);
          _emit(
            QudsOp.oBinOp,
            cur,
            cur,
            (rhs.reg << 8) | _dynCompoundOp(stmt.operator),
            line,
          );
          _emit(QudsOp.oStoreGlobal, cur, 0, slot, line);
        }
        restoreTemps();
        return;
      }

      if (stmt.operator == '=') {
        // Fused integer list-accumulation pattern: `acc = acc + intList[idx]`!
        if (kind == _RegKind.intT &&
            stmt.value is BinaryExpression &&
            (stmt.value as BinaryExpression).operator == '+' &&
            (stmt.value as BinaryExpression).left is Identifier &&
            ((stmt.value as BinaryExpression).left as Identifier).name ==
                stmt.name &&
            (stmt.value as BinaryExpression).right is IndexExpression) {
          final idxExpr =
              (stmt.value as BinaryExpression).right as IndexExpression;
          if (compiler._inferExprKind(idxExpr.object, _varKinds) ==
              _RegKind.listIntT) {
            final target = _compileExpr(idxExpr.object);
            final idx = _coerce(
              _compileExpr(idxExpr.index, desired: _RegKind.intT),
              _RegKind.intT,
              line,
            );
            _emit(QudsOp.iAddListGet, reg, target.reg, idx.reg, line);
            restoreTemps();
            return;
          }
        }
        // Fused multiply-add pattern: `acc = acc + (x * y)`!
        if (kind == _RegKind.doubleT &&
            stmt.value is BinaryExpression &&
            (stmt.value as BinaryExpression).operator == '+' &&
            (stmt.value as BinaryExpression).left is Identifier &&
            ((stmt.value as BinaryExpression).left as Identifier).name ==
                stmt.name &&
            (stmt.value as BinaryExpression).right is BinaryExpression &&
            ((stmt.value as BinaryExpression).right as BinaryExpression)
                    .operator ==
                '*') {
          final mul =
              (stmt.value as BinaryExpression).right as BinaryExpression;
          final a = _coerce(
            _compileExpr(mul.left, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          final b = _coerce(
            _compileExpr(mul.right, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          _emit(QudsOp.fMulAdd, reg, a.reg, b.reg, line);
          restoreTemps();
          return;
        }
        if (stmt.value is ListExpression &&
            (stmt.value as ListExpression).elements.isEmpty) {
          if (kind == _RegKind.listIntT) {
            _emit(QudsOp.newIntList, reg, 0, 0, line);
          } else if (kind == _RegKind.listDoubleT) {
            _emit(QudsOp.newFloatList, reg, 0, 0, line);
          } else {
            _emit(QudsOp.newObjList, reg, 0, 0, line);
          }
        } else {
          _compileExprInto(stmt.value, kind, reg);
        }
      } else {
        _compileCompoundAssign(stmt.operator, kind, reg, stmt.value, line);
      }
      restoreTemps();
      return;
    }

    if (stmt is IndexAssignment) {
      if (stmt.operator != '=') throw const _UnsupportedBytecode();
      final listVal = _compileExpr(stmt.target.object);
      final idxVal = _coerce(
        _compileExpr(stmt.target.index, desired: _RegKind.intT),
        _RegKind.intT,
        line,
      );
      if (listVal.kind == _RegKind.listIntT) {
        final rhs = _coerce(
          _compileExpr(stmt.value, desired: _RegKind.intT),
          _RegKind.intT,
          line,
        );
        _emit(QudsOp.intListSet, listVal.reg, idxVal.reg, rhs.reg, line);
      } else if (listVal.kind == _RegKind.listDoubleT) {
        final rhs = _coerce(
          _compileExpr(stmt.value, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        _emit(QudsOp.floatListSet, listVal.reg, idxVal.reg, rhs.reg, line);
      } else {
        final rhs = _coerce(_compileExpr(stmt.value), _RegKind.objT, line);
        _emit(QudsOp.objListSet, listVal.reg, idxVal.reg, rhs.reg, line);
      }
      restoreTemps();
      return;
    }

    if (stmt is ExpressionStatement) {
      // Avoid emitting dead `O_LOAD_K(null)` for void statement calls like
      // `list.add(x)` and `print(x)` inside hot loops!
      if (!_tryCompileVoidExprStmt(stmt.expression, line)) {
        _compileExpr(stmt.expression);
      }
      restoreTemps();
      return;
    }

    if (stmt is ReturnStatement) {
      if (stmt.value == null) {
        _emit(QudsOp.retVoid, 0, 0, 0, line);
      } else {
        final rk = expectedReturnKind ?? _RegKind.objT;
        final v = _compileExpr(stmt.value!, desired: rk);
        _emitReturn(v, rk, line);
      }
      restoreTemps();
      return;
    }

    if (stmt is IfStatement) {
      final jFalse = _emitJumpIfFalse(stmt.condition, line);
      for (final s in stmt.thenBody) {
        _compileStmt(s, expectedReturnKind: expectedReturnKind);
      }
      if (stmt.elseBody.isNotEmpty) {
        final jEnd = _emit(QudsOp.jump, 0, 0, 0, line);
        _clearCse();
        _patchJumpList(jFalse, _code.length);
        for (final s in stmt.elseBody) {
          _compileStmt(s, expectedReturnKind: expectedReturnKind);
        }
        _patchC(jEnd, _code.length);
      } else {
        _patchJumpList(jFalse, _code.length);
      }
      _clearCse();
      restoreTemps();
      return;
    }

    if (stmt is WhileStatement) {
      if (stmt.elseBody.isNotEmpty) throw const _UnsupportedBytecode();
      // Loop Inversion with fused counted back-edge (`I_INC_JLT` / `I_INC_JLE`)
      // when `while i < limit:` or `while i <= limit:` ends with `i = i + 1`
      // (or `i += 1`) and has no `continue` statements in the body.
      final inverted = _tryMatchCountedWhile(stmt);
      if (inverted != null) {
        final (iterReg, limitReg, inclusive) = inverted;
        final preExitIp = _emit(
          inclusive ? QudsOp.iJgt : QudsOp.iJge,
          iterReg,
          limitReg,
          0,
          line,
        );
        _clearCse();
        final loopBody = _code.length;
        final patch = _LoopPatch(loopBody);
        _loopStack.add(patch);
        final body = stmt.body;
        for (var i = 0; i < body.length - 1; i++) {
          _compileStmt(body[i], expectedReturnKind: expectedReturnKind);
        }
        _emit(
          inclusive ? QudsOp.iIncJle : QudsOp.iIncJlt,
          iterReg,
          limitReg,
          loopBody,
          body.last.span.line,
        );
        final afterLoop = _code.length;
        _clearCse();
        _patchC(preExitIp, afterLoop);
        for (final b in patch.breaks) {
          _patchC(b, afterLoop);
        }
        _loopStack.removeLast();
        restoreTemps();
        return;
      }

      _clearCse();
      final loopStart = _code.length;
      final patch = _LoopPatch(loopStart);
      _loopStack.add(patch);
      final exitJumps = _emitJumpIfFalse(stmt.condition, line);
      // Keep condition temporaries pinned across the loop body so pure
      // subexpressions computed in the loop header (e.g. `zx * zx`) can be
      // reused by the body via local CSE with zero extra ops!
      var fusedLatch = false;
      final body = stmt.body;
      for (var i = 0; i < body.length; i++) {
        final s = body[i];
        if (i == body.length - 1 && _tryEmitFusedWhileLatch(s, loopStart)) {
          fusedLatch = true;
          break;
        }
        _compileStmt(s, expectedReturnKind: expectedReturnKind);
      }
      if (!fusedLatch) {
        _emit(QudsOp.jump, 0, 0, loopStart, line);
      }
      final afterLoop = _code.length;
      _clearCse();
      _patchJumpList(exitJumps, afterLoop);
      for (final b in patch.breaks) {
        _patchC(b, afterLoop);
      }
      for (final c in patch.continues) {
        _patchC(c, loopStart);
      }
      _loopStack.removeLast();
      restoreTemps();
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
      final iterReg = _varRegs[stmt.name]!;
      _compileExprInto(range.start, _RegKind.intT, iterReg);
      final endReg = _allocI();
      _compileExprInto(range.end, _RegKind.intT, endReg);
      int? stepImm;
      var stepReg = -1;
      if (stmt.step == null) {
        stepImm = 1;
      } else if (stmt.step is Literal && (stmt.step as Literal).value is int) {
        stepImm = (stmt.step as Literal).value as int;
      } else {
        stepReg = _allocI();
        _compileExprInto(stmt.step!, _RegKind.intT, stepReg);
      }

      if (stepImm == 1) {
        final preExitIp = _emit(
          range.inclusive ? QudsOp.iJgt : QudsOp.iJge,
          iterReg,
          endReg,
          0,
          line,
        );
        _clearCse();
        final loopBody = _code.length;
        final patch = _LoopPatch(-1);
        _loopStack.add(patch);
        for (final s in stmt.body) {
          _compileStmt(s, expectedReturnKind: expectedReturnKind);
        }
        final stepIp = _code.length;
        _emit(
          range.inclusive ? QudsOp.iIncJle : QudsOp.iIncJlt,
          iterReg,
          endReg,
          loopBody,
          line,
        );
        final afterLoop = _code.length;
        _clearCse();
        _patchC(preExitIp, afterLoop);
        for (final b in patch.breaks) {
          _patchC(b, afterLoop);
        }
        for (final c in patch.continues) {
          _patchC(c, stepIp);
        }
        _loopStack.removeLast();
        restoreTemps();
        return;
      }

      _clearCse();
      final loopStart = _code.length;
      final exitIp = _emit(
        range.inclusive ? QudsOp.iJgt : QudsOp.iJge,
        iterReg,
        endReg,
        0,
        line,
      );
      final patch = _LoopPatch(-1);
      _loopStack.add(patch);
      for (final s in stmt.body) {
        _compileStmt(s, expectedReturnKind: expectedReturnKind);
      }
      final stepIp = _code.length;
      if (stepImm != null && stepImm >= -512 && stepImm <= 511) {
        _emit(QudsOp.iIncJump, iterReg, stepImm + 512, loopStart, line);
      } else if (stepImm != null) {
        _emit(QudsOp.iAddImm, iterReg, iterReg, stepImm, line);
        _emit(QudsOp.jump, 0, 0, loopStart, line);
      } else {
        _emit(QudsOp.iAddJump, iterReg, stepReg, loopStart, line);
      }
      final afterLoop = _code.length;
      _clearCse();
      _patchC(exitIp, afterLoop);
      for (final b in patch.breaks) {
        _patchC(b, afterLoop);
      }
      for (final c in patch.continues) {
        _patchC(c, stepIp);
      }
      _loopStack.removeLast();
      restoreTemps();
      return;
    }

    if (stmt is RepeatStatement) {
      if (stmt.count == null) throw const _UnsupportedBytecode();
      final cntReg = _allocI();
      _compileExprInto(stmt.count!, _RegKind.intT, cntReg);
      final zeroConst = _addIConst(0);
      _clearCse();
      final loopStart = _code.length;
      final exitIp = _emit(QudsOp.iJleK, cntReg, zeroConst, 0, line);
      final patch = _LoopPatch(-1);
      _loopStack.add(patch);
      for (final s in stmt.body) {
        _compileStmt(s, expectedReturnKind: expectedReturnKind);
      }
      final stepIp = _code.length;
      _emit(QudsOp.iIncJump, cntReg, 511, loopStart, line);
      final afterLoop = _code.length;
      _clearCse();
      _patchC(exitIp, afterLoop);
      for (final b in patch.breaks) {
        _patchC(b, afterLoop);
      }
      for (final c in patch.continues) {
        _patchC(c, stepIp);
      }
      _loopStack.removeLast();
      restoreTemps();
      return;
    }

    if (stmt is BreakStatement && stmt.label == null && _loopStack.isNotEmpty) {
      _loopStack.last.breaks.add(_emit(QudsOp.jump, 0, 0, 0, line));
      return;
    }

    if (stmt is ContinueStatement &&
        stmt.label == null &&
        _loopStack.isNotEmpty) {
      _loopStack.last.continues.add(_emit(QudsOp.jump, 0, 0, 0, line));
      return;
    }

    throw const _UnsupportedBytecode();
  }

  bool _containsContinue(List<Statement> stmts) {
    for (final s in stmts) {
      if (s is ContinueStatement) return true;
      if (s is IfStatement) {
        if (_containsContinue(s.thenBody) || _containsContinue(s.elseBody)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Matches `while i < limit:` or `while i <= limit:` where `i` and `limit`
  /// are local `intT` variables, the body has no `continue`, and the last
  /// statement is `i = i + 1` or `i += 1`.
  (int iterReg, int limitReg, bool inclusive)? _tryMatchCountedWhile(
    WhileStatement stmt,
  ) {
    if (stmt.body.isEmpty) return null;
    final cond = stmt.condition;
    if (cond is! BinaryExpression) return null;
    if (cond.operator != '<' && cond.operator != '<=') return null;
    if (cond.left is! Identifier || cond.right is! Identifier) return null;
    final iterName = (cond.left as Identifier).name;
    final limitName = (cond.right as Identifier).name;
    if (isMain &&
        (compiler._sharedGlobals.contains(iterName) ||
            compiler._sharedGlobals.contains(limitName))) {
      return null;
    }
    if (_varKinds[iterName] != _RegKind.intT ||
        _varKinds[limitName] != _RegKind.intT) {
      return null;
    }
    final iterReg = _varRegs[iterName];
    final limitReg = _varRegs[limitName];
    if (iterReg == null || limitReg == null) return null;

    final last = stmt.body.last;
    if (last is! Binding || last.name != iterName) return null;
    if (last.mode == BindingMode.lateFinal ||
        last.mode == BindingMode.lateMutable) {
      return null;
    }
    var isPlusOne = false;
    if (last.operator == '=' && last.value is BinaryExpression) {
      final bin = last.value as BinaryExpression;
      if (bin.operator == '+' &&
          bin.left is Identifier &&
          (bin.left as Identifier).name == iterName &&
          bin.right is Literal &&
          (bin.right as Literal).value == 1) {
        isPlusOne = true;
      }
    } else if (last.operator == '+=' &&
        last.value is Literal &&
        (last.value as Literal).value == 1) {
      isPlusOne = true;
    }
    if (!isPlusOne) return null;
    if (_containsContinue(stmt.body)) return null;
    return (iterReg, limitReg, cond.operator == '<=');
  }

  /// Compiles void-returning statement calls (`list.add(x)`, `print(x)`)
  /// without emitting a dead `O_LOAD_K(null)` result register.
  bool _tryCompileVoidExprStmt(Expression expr, int line) {
    if (expr is! CallExpression) return false;
    if (expr.arguments.any((a) => a.name != null)) return false;

    if (expr.callee is MemberAccess) {
      final mem = expr.callee as MemberAccess;
      if (mem.name == 'add' && expr.arguments.length == 1) {
        final target = _compileExpr(mem.object);
        if (target.kind == _RegKind.listIntT) {
          final v = _coerce(
            _compileExpr(expr.arguments.first.value, desired: _RegKind.intT),
            _RegKind.intT,
            line,
          );
          _emit(QudsOp.intListAdd, target.reg, v.reg, 0, line);
          return true;
        }
        if (target.kind == _RegKind.listDoubleT) {
          final v = _coerce(
            _compileExpr(expr.arguments.first.value, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          _emit(QudsOp.floatListAdd, target.reg, v.reg, 0, line);
          return true;
        }
        final v = _coerce(
          _compileExpr(expr.arguments.first.value),
          _RegKind.objT,
          line,
        );
        _emit(QudsOp.objListAdd, target.reg, v.reg, 0, line);
        return true;
      }
    } else if (expr.callee is Identifier) {
      final cname = (expr.callee as Identifier).name;
      if (cname == 'print' && expr.arguments.length == 1) {
        final v = _compileExpr(expr.arguments.first.value);
        switch (v.kind) {
          case _RegKind.intT:
            _emit(QudsOp.printI, v.reg, 0, 0, line);
          case _RegKind.doubleT:
            _emit(QudsOp.printF, v.reg, 0, 0, line);
          default:
            final o = _coerce(v, _RegKind.objT, line);
            _emit(QudsOp.printO, o.reg, 0, 0, line);
        }
        return true;
      }
    }
    return false;
  }

  void _compileCompoundAssign(
    String op,
    _RegKind kind,
    int dstReg,
    Expression rhsExpr,
    int line,
  ) {
    if (kind == _RegKind.intT && op != '/=') {
      if (op == '+=' && rhsExpr is IndexExpression) {
        if (compiler._inferExprKind(rhsExpr.object, _varKinds) ==
            _RegKind.listIntT) {
          final target = _compileExpr(rhsExpr.object);
          final idx = _coerce(
            _compileExpr(rhsExpr.index, desired: _RegKind.intT),
            _RegKind.intT,
            line,
          );
          _emit(QudsOp.iAddListGet, dstReg, target.reg, idx.reg, line);
          return;
        }
      }
      if ((op == '+=' || op == '-=') &&
          rhsExpr is Literal &&
          rhsExpr.value is int) {
        final v = rhsExpr.value as int;
        final delta = op == '+=' ? v : -v;
        if (delta >= -2147483648 && delta <= 2147483647) {
          _emit(QudsOp.iAddImm, dstReg, dstReg, delta, line);
          return;
        }
      }
      final rhs = _coerce(_compileExpr(rhsExpr), _RegKind.intT, line);
      final opcode = switch (op) {
        '+=' => QudsOp.iAdd,
        '-=' => QudsOp.iSub,
        '*=' => QudsOp.iMul,
        '~/=' => QudsOp.iIdiv,
        '%=' => QudsOp.iMod,
        _ => throw const _UnsupportedBytecode(),
      };
      _emit(opcode, dstReg, dstReg, rhs.reg, line);
      return;
    }
    if (kind == _RegKind.doubleT) {
      if (op == '+=' &&
          rhsExpr is BinaryExpression &&
          rhsExpr.operator == '*') {
        final a = _coerce(
          _compileExpr(rhsExpr.left, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        final b = _coerce(
          _compileExpr(rhsExpr.right, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        _emit(QudsOp.fMulAdd, dstReg, a.reg, b.reg, line);
        return;
      }
      final rhs = _coerce(_compileExpr(rhsExpr), _RegKind.doubleT, line);
      final opcode = switch (op) {
        '+=' => QudsOp.fAdd,
        '-=' => QudsOp.fSub,
        '*=' => QudsOp.fMul,
        '/=' => QudsOp.fDiv,
        _ => throw const _UnsupportedBytecode(),
      };
      _emit(opcode, dstReg, dstReg, rhs.reg, line);
      return;
    }
    final rhs = _coerce(_compileExpr(rhsExpr), _RegKind.objT, line);
    _emit(
      QudsOp.oBinOp,
      dstReg,
      dstReg,
      (rhs.reg << 8) | _dynCompoundOp(op),
      line,
    );
  }

  static int _dynCompoundOp(String op) => switch (op) {
        '+=' => _DynBinOp.add,
        '-=' => _DynBinOp.sub,
        '*=' => _DynBinOp.mul,
        '/=' => _DynBinOp.div,
        '~/=' => _DynBinOp.idiv,
        '%=' => _DynBinOp.mod,
        _ => throw const _UnsupportedBytecode(),
      };

  List<int> _emitJumpIfFalse(Expression cond, int line) {
    if (cond is Literal && cond.value is bool) {
      if (cond.value as bool) return const [];
      return [_emit(QudsOp.jump, 0, 0, 0, line)];
    }
    if (cond is BinaryExpression &&
        (cond.operator == 'and' || cond.operator == '&&')) {
      final leftExits = _emitJumpIfFalse(cond.left, line);
      final rightExits = _emitJumpIfFalse(cond.right, line);
      return [...leftExits, ...rightExits];
    }
    if (cond is BinaryExpression &&
        const {'<', '<=', '>', '>=', '==', '!='}.contains(cond.operator)) {
      final lKind = compiler._inferExprKind(cond.left, _varKinds);
      final rKind = compiler._inferExprKind(cond.right, _varKinds);

      if (lKind == _RegKind.intT && rKind == _RegKind.intT) {
        if (cond.right is Literal && (cond.right as Literal).value is int) {
          final lhs = _compileExpr(cond.left, desired: _RegKind.intT);
          final kIdx = _addIConst((cond.right as Literal).value as int);
          final jumpOp = switch (cond.operator) {
            '<' => QudsOp.iJgeK,
            '<=' => QudsOp.iJgtK,
            '>' => QudsOp.iJleK,
            '>=' => QudsOp.iJltK,
            '==' => QudsOp.iJneK,
            '!=' => QudsOp.iJeqK,
            _ => throw const _UnsupportedBytecode(),
          };
          return [_emit(jumpOp, lhs.reg, kIdx, 0, line)];
        }
        final lhs = _compileExpr(cond.left, desired: _RegKind.intT);
        final rhs = _compileExpr(cond.right, desired: _RegKind.intT);
        final jumpOp = switch (cond.operator) {
          '<' => QudsOp.iJge,
          '<=' => QudsOp.iJgt,
          '>' => QudsOp.iJle,
          '>=' => QudsOp.iJlt,
          '==' => QudsOp.iJne,
          '!=' => QudsOp.iJeq,
          _ => throw const _UnsupportedBytecode(),
        };
        return [_emit(jumpOp, lhs.reg, rhs.reg, 0, line)];
      }

      if (QudsBytecodeCompiler._isNumKind(lKind) &&
          QudsBytecodeCompiler._isNumKind(rKind) &&
          const {'<', '<=', '>', '>='}.contains(cond.operator)) {
        if (cond.operator == '<=' &&
            cond.right is Literal &&
            (cond.right as Literal).value is num) {
          final lhs = _coerce(
            _compileExpr(cond.left, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          final kIdx =
              _addFConst(((cond.right as Literal).value as num).toDouble());
          return [_emit(QudsOp.fJgtK, lhs.reg, kIdx, 0, line)];
        }
        final lhs = _coerce(
          _compileExpr(cond.left, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        final rhs = _coerce(
          _compileExpr(cond.right, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        final jumpOp = switch (cond.operator) {
          '<' => QudsOp.fJge,
          '<=' => QudsOp.fJgt,
          '>' => QudsOp.fJle,
          '>=' => QudsOp.fJlt,
          _ => throw const _UnsupportedBytecode(),
        };
        return [_emit(jumpOp, lhs.reg, rhs.reg, 0, line)];
      }
    }

    final v = _coerce(_compileExpr(cond), _RegKind.objT, line);
    return [_emit(QudsOp.oJumpIfFalse, v.reg, 0, 0, line)];
  }

  void _patchJumpList(List<int> jumps, int targetIp) {
    for (final j in jumps) {
      _patchC(j, targetIp);
    }
  }

  void _compileExprInto(Expression expr, _RegKind dstKind, int dstReg) {
    final line = expr.span.line;

    if (dstKind == _RegKind.intT && expr is Literal && expr.value is int) {
      final v = expr.value as int;
      final hoisted = _hoistedIRegs[v];
      if (hoisted != null) {
        _emit(QudsOp.iMove, dstReg, hoisted, 0, line);
        return;
      }
      if (v >= -2147483648 && v <= 2147483647) {
        _emit(QudsOp.iLoadImm, dstReg, 0, v, line);
      } else {
        _emit(QudsOp.iLoadK, dstReg, 0, _addIConst(v), line);
      }
      return;
    }

    if (dstKind == _RegKind.doubleT && expr is Literal && expr.value is num) {
      final d = (expr.value as num).toDouble();
      final hoisted = _hoistedFRegs[d];
      if (hoisted != null) {
        _emit(QudsOp.fMove, dstReg, hoisted, 0, line);
        return;
      }
      _emit(QudsOp.fLoadK, dstReg, 0, _addFConst(d), line);
      return;
    }

    if (dstKind == _RegKind.intT &&
        expr is BinaryExpression &&
        (expr.operator == '+' || expr.operator == '-') &&
        expr.right is Literal &&
        (expr.right as Literal).value is int) {
      final rv = (expr.right as Literal).value as int;
      final delta = expr.operator == '+' ? rv : -rv;
      if (delta >= -2147483648 && delta <= 2147483647) {
        final l = _coerce(
          _compileExpr(expr.left, desired: _RegKind.intT),
          _RegKind.intT,
          line,
        );
        _emit(QudsOp.iAddImm, dstReg, l.reg, delta, line);
        return;
      }
    }

    if (expr is BinaryExpression) {
      if (_tryCompileBinaryInto(expr, dstKind, dstReg)) return;
    }

    if (dstKind == _RegKind.doubleT && expr is CallExpression) {
      if (_tryCompileCallInto(expr, dstKind, dstReg)) return;
    }

    final val = _compileExpr(expr, desired: dstKind);
    final coerced = _coerce(val, dstKind, line);
    if (coerced.reg == dstReg) return;
    switch (dstKind) {
      case _RegKind.intT:
        _emit(QudsOp.iMove, dstReg, coerced.reg, 0, line);
      case _RegKind.doubleT:
        _emit(QudsOp.fMove, dstReg, coerced.reg, 0, line);
      default:
        _emit(QudsOp.oMove, dstReg, coerced.reg, 0, line);
    }
  }

  bool _tryCompileBinaryInto(
      BinaryExpression expr, _RegKind dstKind, int dstReg) {
    final line = expr.span.line;
    final op = expr.operator;
    final lK = compiler._inferExprKind(expr.left, _varKinds);
    final rK = compiler._inferExprKind(expr.right, _varKinds);

    if (dstKind == _RegKind.intT &&
        lK == _RegKind.intT &&
        rK == _RegKind.intT &&
        const {'+', '-', '*', '~/', '%'}.contains(op)) {
      if ((op == '+' || op == '-') &&
          expr.right is Literal &&
          (expr.right as Literal).value is int) {
        final rv = (expr.right as Literal).value as int;
        final delta = op == '+' ? rv : -rv;
        if (delta >= -2147483648 && delta <= 2147483647) {
          final l = _compileExpr(expr.left, desired: _RegKind.intT);
          _emit(QudsOp.iAddImm, dstReg, l.reg, delta, line);
          return true;
        }
      }
      final l = _compileExpr(expr.left, desired: _RegKind.intT);
      final r = _compileExpr(expr.right, desired: _RegKind.intT);
      final opcode = switch (op) {
        '+' => QudsOp.iAdd,
        '-' => QudsOp.iSub,
        '*' => QudsOp.iMul,
        '~/' => QudsOp.iIdiv,
        '%' => QudsOp.iMod,
        _ => throw const _UnsupportedBytecode(),
      };
      if (opcode == QudsOp.iAdd ||
          opcode == QudsOp.iSub ||
          opcode == QudsOp.iMul) {
        final key = _cseKey(opcode, l.reg, r.reg);
        final cached = _cseI[key];
        if (cached != null) {
          if (cached != dstReg) _emit(QudsOp.iMove, dstReg, cached, 0, line);
          return true;
        }
        _emit(opcode, dstReg, l.reg, r.reg, line);
        if (dstReg != l.reg && dstReg != r.reg) {
          _cseI[key] = dstReg;
        }
        return true;
      }
      _emit(opcode, dstReg, l.reg, r.reg, line);
      return true;
    }

    if (dstKind == _RegKind.doubleT &&
        QudsBytecodeCompiler._isNumKind(lK) &&
        QudsBytecodeCompiler._isNumKind(rK) &&
        const {'+', '-', '*', '/'}.contains(op)) {
      if (op == '/' && lK == _RegKind.intT && rK == _RegKind.intT) {
        final l = _compileExpr(expr.left, desired: _RegKind.intT);
        final r = _compileExpr(expr.right, desired: _RegKind.intT);
        _emit(QudsOp.iDivF, dstReg, l.reg, r.reg, line);
        return true;
      }
      final l = _coerce(
        _compileExpr(expr.left, desired: _RegKind.doubleT),
        _RegKind.doubleT,
        line,
      );
      final r = _coerce(
        _compileExpr(expr.right, desired: _RegKind.doubleT),
        _RegKind.doubleT,
        line,
      );
      final opcode = switch (op) {
        '+' => QudsOp.fAdd,
        '-' => QudsOp.fSub,
        '*' => QudsOp.fMul,
        '/' => QudsOp.fDiv,
        _ => throw const _UnsupportedBytecode(),
      };
      final key = _cseKey(opcode, l.reg, r.reg);
      final cached = _cseF[key];
      if (cached != null) {
        if (cached != dstReg) _emit(QudsOp.fMove, dstReg, cached, 0, line);
        return true;
      }
      _emit(opcode, dstReg, l.reg, r.reg, line);
      if (dstReg != l.reg && dstReg != r.reg) {
        _cseF[key] = dstReg;
      }
      return true;
    }

    return false;
  }

  _Val? _tryCompileTypedBinaryExpr(BinaryExpression expr, _RegKind inferred) {
    final line = expr.span.line;
    final op = expr.operator;
    final lK = compiler._inferExprKind(expr.left, _varKinds);
    final rK = compiler._inferExprKind(expr.right, _varKinds);

    if (inferred == _RegKind.intT &&
        lK == _RegKind.intT &&
        rK == _RegKind.intT &&
        const {'+', '-', '*', '~/', '%'}.contains(op)) {
      if ((op == '+' || op == '-') &&
          expr.right is Literal &&
          (expr.right as Literal).value is int) {
        final rv = (expr.right as Literal).value as int;
        final delta = op == '+' ? rv : -rv;
        if (delta >= -2147483648 && delta <= 2147483647) {
          final l = _compileExpr(expr.left, desired: _RegKind.intT);
          final dst = _allocI();
          _emit(QudsOp.iAddImm, dst, l.reg, delta, line);
          return _Val(_RegKind.intT, dst, isTemp: true);
        }
      }
      final l = _compileExpr(expr.left, desired: _RegKind.intT);
      final r = _compileExpr(expr.right, desired: _RegKind.intT);
      final opcode = switch (op) {
        '+' => QudsOp.iAdd,
        '-' => QudsOp.iSub,
        '*' => QudsOp.iMul,
        '~/' => QudsOp.iIdiv,
        '%' => QudsOp.iMod,
        _ => throw const _UnsupportedBytecode(),
      };
      if (opcode == QudsOp.iAdd ||
          opcode == QudsOp.iSub ||
          opcode == QudsOp.iMul) {
        final key = _cseKey(opcode, l.reg, r.reg);
        final cached = _cseI[key];
        if (cached != null) {
          return _Val(_RegKind.intT, cached, isTemp: false);
        }
        final dst = _allocI();
        _emit(opcode, dst, l.reg, r.reg, line);
        _cseI[key] = dst;
        return _Val(_RegKind.intT, dst, isTemp: true);
      }
      final dst = _allocI();
      _emit(opcode, dst, l.reg, r.reg, line);
      return _Val(_RegKind.intT, dst, isTemp: true);
    }

    if (inferred == _RegKind.doubleT &&
        QudsBytecodeCompiler._isNumKind(lK) &&
        QudsBytecodeCompiler._isNumKind(rK) &&
        const {'+', '-', '*', '/'}.contains(op)) {
      if (op == '/' && lK == _RegKind.intT && rK == _RegKind.intT) {
        final l = _compileExpr(expr.left, desired: _RegKind.intT);
        final r = _compileExpr(expr.right, desired: _RegKind.intT);
        final dst = _allocF();
        _emit(QudsOp.iDivF, dst, l.reg, r.reg, line);
        return _Val(_RegKind.doubleT, dst, isTemp: true);
      }
      final l = _coerce(
        _compileExpr(expr.left, desired: _RegKind.doubleT),
        _RegKind.doubleT,
        line,
      );
      final r = _coerce(
        _compileExpr(expr.right, desired: _RegKind.doubleT),
        _RegKind.doubleT,
        line,
      );
      final opcode = switch (op) {
        '+' => QudsOp.fAdd,
        '-' => QudsOp.fSub,
        '*' => QudsOp.fMul,
        '/' => QudsOp.fDiv,
        _ => throw const _UnsupportedBytecode(),
      };
      final key = _cseKey(opcode, l.reg, r.reg);
      final cached = _cseF[key];
      if (cached != null) {
        return _Val(_RegKind.doubleT, cached, isTemp: false);
      }
      final dst = _allocF();
      _emit(opcode, dst, l.reg, r.reg, line);
      _cseF[key] = dst;
      return _Val(_RegKind.doubleT, dst, isTemp: true);
    }

    return null;
  }

  bool _isMathIntrinsicCall(CallExpression expr) {
    if (expr.arguments.any((a) => a.name != null)) return false;
    String? mathName;
    if (expr.callee is Identifier) {
      mathName = (expr.callee as Identifier).name;
    } else if (expr.callee is MemberAccess) {
      final m = expr.callee as MemberAccess;
      if (m.object is Identifier &&
          compiler._mathPrefixes.contains((m.object as Identifier).name)) {
        mathName = m.name;
      }
    }
    if (mathName == null) return false;
    if (mathName == 'sqrt' && expr.arguments.length == 1) return true;
    if (_unaryMathIntr(mathName) != null && expr.arguments.length == 1) {
      return true;
    }
    if (_binaryMathIntr(mathName) != null && expr.arguments.length == 2) {
      return true;
    }
    return false;
  }

  bool _tryCompileCallInto(CallExpression expr, _RegKind dstKind, int dstReg) {
    final line = expr.span.line;
    if (expr.arguments.any((a) => a.name != null)) return false;

    String? mathName;
    if (expr.callee is Identifier) {
      mathName = (expr.callee as Identifier).name;
    } else if (expr.callee is MemberAccess) {
      final m = expr.callee as MemberAccess;
      if (m.object is Identifier &&
          compiler._mathPrefixes.contains((m.object as Identifier).name)) {
        mathName = m.name;
      }
    }
    if (mathName != null && dstKind == _RegKind.doubleT) {
      if (mathName == 'sqrt' && expr.arguments.length == 1) {
        final a = _coerce(
          _compileExpr(expr.arguments.first.value, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        _emit(QudsOp.fSqrt, dstReg, a.reg, 0, line);
        return true;
      }
      final intr1 = _unaryMathIntr(mathName);
      if (intr1 != null && expr.arguments.length == 1) {
        final a = _coerce(
          _compileExpr(expr.arguments.first.value, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        _emit(QudsOp.fIntrinsic, dstReg, a.reg, intr1, line);
        return true;
      }
      final intr2 = _binaryMathIntr(mathName);
      if (intr2 != null && expr.arguments.length == 2) {
        final a = _coerce(
          _compileExpr(expr.arguments[0].value, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        final b = _coerce(
          _compileExpr(expr.arguments[1].value, desired: _RegKind.doubleT),
          _RegKind.doubleT,
          line,
        );
        _emit(QudsOp.fIntrinsic2, dstReg, a.reg, (b.reg << 8) | intr2, line);
        return true;
      }
    }

    return false;
  }

  static int? _unaryMathIntr(String name) => switch (name) {
        'sin' => _Intr.sin,
        'cos' => _Intr.cos,
        'tan' => _Intr.tan,
        'abs' => _Intr.abs,
        'exp' => _Intr.exp,
        'log' => _Intr.log,
        'floor' => _Intr.floor,
        'ceil' => _Intr.ceil,
        'round' => _Intr.round,
        _ => null,
      };

  static int? _binaryMathIntr(String name) => switch (name) {
        'pow' => _Intr.pow,
        'min' => _Intr.min,
        'max' => _Intr.max,
        _ => null,
      };

  _Val _compileExpr(Expression expr, {_RegKind? desired}) {
    final line = expr.span.line;

    if (expr is Literal) {
      final v = expr.value;
      if (v is int) {
        if (desired == _RegKind.doubleT) {
          final d = v.toDouble();
          final hoisted = _hoistedFRegs[d];
          if (hoisted != null) {
            return _Val(_RegKind.doubleT, hoisted, isTemp: false);
          }
          final dst = _allocF();
          _emit(QudsOp.fLoadK, dst, 0, _addFConst(d), line);
          return _Val(_RegKind.doubleT, dst, isTemp: true);
        }
        final hoisted = _hoistedIRegs[v];
        if (hoisted != null) {
          return _Val(_RegKind.intT, hoisted, isTemp: false);
        }
        final dst = _allocI();
        if (v >= -2147483648 && v <= 2147483647) {
          _emit(QudsOp.iLoadImm, dst, 0, v, line);
        } else {
          _emit(QudsOp.iLoadK, dst, 0, _addIConst(v), line);
        }
        return _Val(_RegKind.intT, dst, isTemp: true);
      }
      if (v is double) {
        final hoisted = _hoistedFRegs[v];
        if (hoisted != null) {
          return _Val(_RegKind.doubleT, hoisted, isTemp: false);
        }
        final dst = _allocF();
        _emit(QudsOp.fLoadK, dst, 0, _addFConst(v), line);
        return _Val(_RegKind.doubleT, dst, isTemp: true);
      }
      final dst = _allocO();
      _emit(QudsOp.oLoadK, dst, 0, _addOConst(v), line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }

    if (expr is Identifier) {
      if (expr.name == 'pi') {
        final dst = _allocF();
        _emit(QudsOp.fLoadK, dst, 0, _addFConst(math.pi), line);
        return _Val(_RegKind.doubleT, dst, isTemp: true);
      }
      if (expr.name == 'e') {
        final dst = _allocF();
        _emit(QudsOp.fLoadK, dst, 0, _addFConst(math.e), line);
        return _Val(_RegKind.doubleT, dst, isTemp: true);
      }
      if (isMain && compiler._sharedGlobals.contains(expr.name)) {
        final dst = _allocO();
        _emit(
          QudsOp.oLoadGlobal,
          dst,
          0,
          compiler._globalSlots[expr.name]!,
          line,
        );
        return _Val(_RegKind.objT, dst, isTemp: true);
      }
      final reg = _varRegs[expr.name];
      final kind = _varKinds[expr.name];
      if (reg != null && kind != null) {
        return _Val(kind, reg, isTemp: false);
      }
      final gSlot = compiler._globalSlots[expr.name];
      if (gSlot != null) {
        final dst = _allocO();
        _emit(QudsOp.oLoadGlobal, dst, 0, gSlot, line);
        return _Val(_RegKind.objT, dst, isTemp: true);
      }
      throw const _UnsupportedBytecode();
    }

    if (expr is UnaryExpression) {
      final v = _compileExpr(expr.operand);
      if (expr.operator == '-') {
        if (v.kind == _RegKind.intT) {
          final dst = _allocI();
          _emit(QudsOp.iNeg, dst, v.reg, 0, line);
          return _Val(_RegKind.intT, dst, isTemp: true);
        }
        if (v.kind == _RegKind.doubleT) {
          final dst = _allocF();
          _emit(QudsOp.fNeg, dst, v.reg, 0, line);
          return _Val(_RegKind.doubleT, dst, isTemp: true);
        }
        final o = _coerce(v, _RegKind.objT, line);
        final dst = _allocO();
        _emit(QudsOp.oUnaryOp, dst, o.reg, 0, line);
        return _Val(_RegKind.objT, dst, isTemp: true);
      }
      if (expr.operator == 'not' || expr.operator == '!') {
        final o = _coerce(v, _RegKind.objT, line);
        final dst = _allocO();
        _emit(QudsOp.oUnaryOp, dst, o.reg, 1, line);
        return _Val(_RegKind.objT, dst, isTemp: true);
      }
      throw const _UnsupportedBytecode();
    }

    if (expr is BinaryExpression) {
      if (expr.operator == 'and' || expr.operator == '&&') {
        final dst = _allocO();
        final l = _coerce(_compileExpr(expr.left), _RegKind.objT, line);
        _emit(QudsOp.oMove, dst, l.reg, 0, line);
        final jEnd = _emit(QudsOp.oJumpIfFalse, dst, 0, 0, line);
        final r = _coerce(_compileExpr(expr.right), _RegKind.objT, line);
        _emit(QudsOp.oMove, dst, r.reg, 0, line);
        _patchC(jEnd, _code.length);
        _clearCse();
        return _Val(_RegKind.objT, dst, isTemp: true);
      }
      if (expr.operator == 'or' || expr.operator == '||') {
        final dst = _allocO();
        final l = _coerce(_compileExpr(expr.left), _RegKind.objT, line);
        _emit(QudsOp.oMove, dst, l.reg, 0, line);
        final jEnd = _emit(QudsOp.oJumpIfTrue, dst, 0, 0, line);
        final r = _coerce(_compileExpr(expr.right), _RegKind.objT, line);
        _emit(QudsOp.oMove, dst, r.reg, 0, line);
        _patchC(jEnd, _code.length);
        _clearCse();
        return _Val(_RegKind.objT, dst, isTemp: true);
      }

      final inferred = compiler._inferExprKind(expr, _varKinds);
      if (inferred == _RegKind.intT || inferred == _RegKind.doubleT) {
        final compiled = _tryCompileTypedBinaryExpr(expr, inferred);
        if (compiled != null) return compiled;
      }

      if (const {'==', '!=', '<', '<=', '>', '>='}.contains(expr.operator)) {
        final cmpId = switch (expr.operator) {
          '==' => _DynBinOp.eq,
          '!=' => _DynBinOp.neq,
          '<' => _DynBinOp.lt,
          '<=' => _DynBinOp.lte,
          '>' => _DynBinOp.gt,
          '>=' => _DynBinOp.gte,
          _ => throw const _UnsupportedBytecode(),
        };
        final lK = compiler._inferExprKind(expr.left, _varKinds);
        final rK = compiler._inferExprKind(expr.right, _varKinds);
        if (lK == _RegKind.intT && rK == _RegKind.intT) {
          final l = _compileExpr(expr.left, desired: _RegKind.intT);
          final r = _compileExpr(expr.right, desired: _RegKind.intT);
          final dst = _allocO();
          _emit(QudsOp.iCmpToO, dst, l.reg, (r.reg << 8) | cmpId, line);
          return _Val(_RegKind.objT, dst, isTemp: true);
        }
        if (QudsBytecodeCompiler._isNumKind(lK) &&
            QudsBytecodeCompiler._isNumKind(rK)) {
          final l = _coerce(
            _compileExpr(expr.left, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          final r = _coerce(
            _compileExpr(expr.right, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          final dst = _allocO();
          _emit(QudsOp.fCmpToO, dst, l.reg, (r.reg << 8) | cmpId, line);
          return _Val(_RegKind.objT, dst, isTemp: true);
        }
      }

      final l = _coerce(_compileExpr(expr.left), _RegKind.objT, line);
      final r = _coerce(_compileExpr(expr.right), _RegKind.objT, line);
      final opId = switch (expr.operator) {
        '+' => _DynBinOp.add,
        '-' => _DynBinOp.sub,
        '*' => _DynBinOp.mul,
        '/' => _DynBinOp.div,
        '~/' => _DynBinOp.idiv,
        '%' => _DynBinOp.mod,
        '==' => _DynBinOp.eq,
        '!=' => _DynBinOp.neq,
        '<' => _DynBinOp.lt,
        '<=' => _DynBinOp.lte,
        '>' => _DynBinOp.gt,
        '>=' => _DynBinOp.gte,
        _ => throw const _UnsupportedBytecode(),
      };
      final dst = _allocO();
      _emit(QudsOp.oBinOp, dst, l.reg, (r.reg << 8) | opId, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }

    if (expr is ListExpression) {
      final listKind = compiler._inferExprKind(expr, _varKinds);
      if (listKind == _RegKind.listIntT) {
        final dst = _allocIL();
        _emit(QudsOp.newIntList, dst, 0, 0, line);
        for (final el in expr.elements) {
          final v = _coerce(
            _compileExpr(el, desired: _RegKind.intT),
            _RegKind.intT,
            line,
          );
          _emit(QudsOp.intListAdd, dst, v.reg, 0, line);
        }
        return _Val(_RegKind.listIntT, dst, isTemp: true);
      }
      if (listKind == _RegKind.listDoubleT) {
        final dst = _allocFL();
        _emit(QudsOp.newFloatList, dst, 0, 0, line);
        for (final el in expr.elements) {
          final v = _coerce(
            _compileExpr(el, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          _emit(QudsOp.floatListAdd, dst, v.reg, 0, line);
        }
        return _Val(_RegKind.listDoubleT, dst, isTemp: true);
      }
      final dst = _allocO();
      _emit(QudsOp.newObjList, dst, 0, 0, line);
      for (final el in expr.elements) {
        final v = _coerce(_compileExpr(el), _RegKind.objT, line);
        _emit(QudsOp.objListAdd, dst, v.reg, 0, line);
      }
      return _Val(_RegKind.objT, dst, isTemp: true);
    }

    if (expr is IndexExpression) {
      final target = _compileExpr(expr.object);
      final idx = _coerce(
        _compileExpr(expr.index, desired: _RegKind.intT),
        _RegKind.intT,
        line,
      );
      if (target.kind == _RegKind.listIntT) {
        final dst = _allocI();
        _emit(QudsOp.intListGet, dst, target.reg, idx.reg, line);
        return _Val(_RegKind.intT, dst, isTemp: true);
      }
      if (target.kind == _RegKind.listDoubleT) {
        final dst = _allocF();
        _emit(QudsOp.floatListGet, dst, target.reg, idx.reg, line);
        return _Val(_RegKind.doubleT, dst, isTemp: true);
      }
      final dst = _allocO();
      _emit(QudsOp.objListGet, dst, target.reg, idx.reg, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }

    if (expr is InterpolatedString) {
      final count = expr.parts.length;
      final start = _oNext;
      final partRegs = <int>[];
      for (var i = 0; i < count; i++) {
        partRegs.add(_allocO());
      }
      for (var i = 0; i < count; i++) {
        final v = _coerce(_compileExpr(expr.parts[i]), _RegKind.objT, line);
        _emit(QudsOp.oMove, partRegs[i], v.reg, 0, line);
      }
      final dst = _allocO();
      _emit(QudsOp.concatStr, dst, start, count, line);
      return _Val(_RegKind.objT, dst, isTemp: true);
    }

    if (expr is MemberAccess) {
      if (expr.object is Identifier &&
          compiler._mathPrefixes.contains((expr.object as Identifier).name)) {
        final val = switch (expr.name) {
          'pi' => math.pi,
          'e' => math.e,
          'ln2' => math.ln2,
          'ln10' => math.ln10,
          'sqrt2' => math.sqrt2,
          _ => null,
        };
        if (val != null) {
          final dst = _allocF();
          _emit(QudsOp.fLoadK, dst, 0, _addFConst(val), line);
          return _Val(_RegKind.doubleT, dst, isTemp: true);
        }
      }
      if (expr.name == 'length') {
        final target = _compileExpr(expr.object);
        final dst = _allocI();
        if (target.kind == _RegKind.listIntT) {
          _emit(QudsOp.intListLen, dst, target.reg, 0, line);
        } else if (target.kind == _RegKind.listDoubleT) {
          _emit(QudsOp.floatListLen, dst, target.reg, 0, line);
        } else {
          _emit(QudsOp.objListLen, dst, target.reg, 0, line);
        }
        return _Val(_RegKind.intT, dst, isTemp: true);
      }
      throw const _UnsupportedBytecode();
    }

    if (expr is CallExpression) {
      if (expr.arguments.any((a) => a.name != null)) {
        throw const _UnsupportedBytecode();
      }

      if (_isMathIntrinsicCall(expr)) {
        final dst = _allocF();
        if (_tryCompileCallInto(expr, _RegKind.doubleT, dst)) {
          return _Val(_RegKind.doubleT, dst, isTemp: true);
        }
      }

      if (expr.callee is Identifier) {
        final cname = (expr.callee as Identifier).name;
        if (cname == 'print' && expr.arguments.length == 1) {
          final v = _compileExpr(expr.arguments.first.value);
          switch (v.kind) {
            case _RegKind.intT:
              _emit(QudsOp.printI, v.reg, 0, 0, line);
            case _RegKind.doubleT:
              _emit(QudsOp.printF, v.reg, 0, 0, line);
            default:
              final o = _coerce(v, _RegKind.objT, line);
              _emit(QudsOp.printO, o.reg, 0, 0, line);
          }
          final dst = _allocO();
          _emit(QudsOp.oLoadK, dst, 0, _addOConst(null), line);
          return _Val(_RegKind.objT, dst, isTemp: true);
        }
        if ((cname == 'double' || cname == 'toDouble') &&
            expr.arguments.length == 1) {
          return _coerce(
            _compileExpr(expr.arguments.first.value, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
        }
        if ((cname == 'int' || cname == 'toInt') &&
            expr.arguments.length == 1) {
          return _coerce(
            _compileExpr(expr.arguments.first.value, desired: _RegKind.intT),
            _RegKind.intT,
            line,
          );
        }

        final fnIdx = compiler._fnIndices[cname];
        if (fnIdx != null) {
          final decl = compiler._fnDecls[cname]!;
          if (expr.arguments.length != decl.parameters.length) {
            throw const _UnsupportedBytecode();
          }
          final pKinds = compiler._fnParamKinds[cname]!;
          final rKind = compiler._fnReturnKinds[cname] ?? _RegKind.objT;

          // Ultra-fast fused self-recursive 1-int-arg call (`fib(n - 1)` -> 1 op!)
          if (_isPureIntSelfRec &&
              fnIdx == selfFnIdx &&
              decl.parameters.length == 1 &&
              pKinds[0] == _RegKind.intT &&
              rKind == _RegKind.intT) {
            final argExpr = expr.arguments[0].value;
            if (argExpr is BinaryExpression &&
                (argExpr.operator == '-' || argExpr.operator == '+') &&
                argExpr.right is Literal &&
                (argExpr.right as Literal).value is int) {
              final raw = (argExpr.right as Literal).value as int;
              final delta = argExpr.operator == '+' ? raw : -raw;
              if (delta >= -1000 && delta <= 1000) {
                final src = _coerce(
                  _compileExpr(argExpr.left, desired: _RegKind.intT),
                  _RegKind.intT,
                  line,
                );
                final dst = _allocI();
                final ip = _emit(QudsOp.callSelfI1Sub, dst, src.reg, 0, line);
                _selfCallPatches.add((ip, delta));
                return _Val(_RegKind.intT, dst, isTemp: true);
              }
            }
            final argV = _coerce(
              _compileExpr(argExpr, desired: _RegKind.intT),
              _RegKind.intT,
              line,
            );
            final dst = _allocI();
            final ip = _emit(QudsOp.callSelfI1Sub, dst, argV.reg, 0, line);
            _selfCallPatches.add((ip, 0));
            return _Val(_RegKind.intT, dst, isTemp: true);
          }

          if (decl.parameters.length == 1 &&
              pKinds[0] == _RegKind.intT &&
              rKind == _RegKind.intT) {
            final argV = _coerce(
              _compileExpr(expr.arguments[0].value, desired: _RegKind.intT),
              _RegKind.intT,
              line,
            );
            final dst = _allocI();
            _emit(QudsOp.callFnI1, dst, argV.reg, fnIdx, line);
            return _Val(_RegKind.intT, dst, isTemp: true);
          }

          final srcBanks = Int32List(decl.parameters.length);
          final srcRegs = Int32List(decl.parameters.length);
          final dstBanks = Int32List(decl.parameters.length);
          final dstRegs = Int32List(decl.parameters.length);
          var pi = 0;
          var pf = 0;
          var po = 0;
          var pil = 0;
          var pfl = 0;
          for (var i = 0; i < decl.parameters.length; i++) {
            final pk = pKinds[i];
            final av = _coerce(
              _compileExpr(expr.arguments[i].value, desired: pk),
              pk,
              line,
            );
            srcBanks[i] = av.bank;
            srcRegs[i] = av.reg;
            final db = _bankFor(pk);
            dstBanks[i] = db;
            dstRegs[i] = switch (db) {
              _Bank.i => pi++,
              _Bank.f => pf++,
              _Bank.il => pil++,
              _Bank.fl => pfl++,
              _ => po++,
            };
          }
          final siteIdx = _callSites.length;
          _callSites.add(_CallSite(
            srcBanks: srcBanks,
            srcRegs: srcRegs,
            dstBanks: dstBanks,
            dstRegs: dstRegs,
            retBank: _bankFor(rKind),
          ));
          final dst = _allocFor(rKind);
          _emit(QudsOp.callFn, dst, siteIdx, fnIdx, line);
          return _Val(rKind, dst, isTemp: true);
        }
        throw const _UnsupportedBytecode();
      }

      if (expr.callee is MemberAccess) {
        final mem = expr.callee as MemberAccess;
        if (mem.name == 'add' && expr.arguments.length == 1) {
          final target = _compileExpr(mem.object);
          if (target.kind == _RegKind.listIntT) {
            final v = _coerce(
              _compileExpr(expr.arguments.first.value, desired: _RegKind.intT),
              _RegKind.intT,
              line,
            );
            _emit(QudsOp.intListAdd, target.reg, v.reg, 0, line);
          } else if (target.kind == _RegKind.listDoubleT) {
            final v = _coerce(
              _compileExpr(expr.arguments.first.value,
                  desired: _RegKind.doubleT),
              _RegKind.doubleT,
              line,
            );
            _emit(QudsOp.floatListAdd, target.reg, v.reg, 0, line);
          } else {
            final v = _coerce(
                _compileExpr(expr.arguments.first.value), _RegKind.objT, line);
            _emit(QudsOp.objListAdd, target.reg, v.reg, 0, line);
          }
          final dst = _allocO();
          _emit(QudsOp.oLoadK, dst, 0, _addOConst(null), line);
          return _Val(_RegKind.objT, dst, isTemp: true);
        }
        if (mem.name == 'toStringAsFixed' && expr.arguments.length == 1) {
          final target = _coerce(
            _compileExpr(mem.object, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          final digits = _coerce(
            _compileExpr(expr.arguments.first.value, desired: _RegKind.intT),
            _RegKind.intT,
            line,
          );
          final dst = _allocO();
          _emit(QudsOp.toFixed, dst, target.reg, digits.reg, line);
          return _Val(_RegKind.objT, dst, isTemp: true);
        }
        if (mem.name == 'abs' && expr.arguments.isEmpty) {
          final target = _coerce(
            _compileExpr(mem.object, desired: _RegKind.doubleT),
            _RegKind.doubleT,
            line,
          );
          final dst = _allocF();
          _emit(QudsOp.fIntrinsic, dst, target.reg, _Intr.abs, line);
          return _Val(_RegKind.doubleT, dst, isTemp: true);
        }
      }
      throw const _UnsupportedBytecode();
    }

    throw const _UnsupportedBytecode();
  }
}

/// High-speed Typed 3-Address Register Bytecode Virtual Machine for Quds.
class QudsBytecodeVm {
  const QudsBytecodeVm._();

  static QudsBytecodeRunResult run(
    QudsBytecodeProgram program, {
    int? maxSteps,
    int maxCallDepth = 256,
    int? maxCollectionLength,
    Duration? timeout,
    void Function(String line)? onPrint,
  }) {
    final stopwatch = Stopwatch()..start();
    final printed = <String>[];
    final functions = program.functions;
    final globals = List<Object?>.filled(program.globalNames.length, null);

    var maxISize = 16;
    var maxFSize = 16;
    var maxOSize = 16;
    var maxILSize = 4;
    var maxFLSize = 4;
    for (final f in functions) {
      if (f.iSize > maxISize) maxISize = f.iSize;
      if (f.fSize > maxFSize) maxFSize = f.fSize;
      if (f.oSize > maxOSize) maxOSize = f.oSize;
      if (f.ilSize > maxILSize) maxILSize = f.ilSize;
      if (f.flSize > maxFLSize) maxFLSize = f.flSize;
    }

    // Pre-allocated flat unboxed register files sized for maxCallDepth so
    // hot recursive calls require ZERO capacity checks or heap allocations!
    final frameLimit = math.max(maxCallDepth + 4, 32);
    final iReg = Int64List(math.max(4096, frameLimit * (maxISize + 1)));
    final fReg = Float64List(math.max(2048, frameLimit * (maxFSize + 1)));
    final oReg =
        List<Object?>.filled(math.max(1024, frameLimit * (maxOSize + 1)), null);
    final ilCap = math.max(256, frameLimit * (maxILSize + 1));
    final flCap = math.max(256, frameLimit * (maxFLSize + 1));
    final emptyI64 = Int64List(0);
    final emptyF64 = Float64List(0);
    final ilReg = List<_QudsIntList?>.filled(ilCap, null);
    final flReg = List<_QudsFloatList?>.filled(flCap, null);
    final ilData = List<Int64List>.filled(ilCap, emptyI64);
    final flData = List<Float64List>.filled(flCap, emptyF64);

    // Flat call-frame return stacks (zero _CallFrame allocations!).
    final retFn = Int32List(frameLimit);
    final retIp = Int32List(frameLimit);
    final retIBp = Int32List(frameLimit);
    final retFBp = Int32List(frameLimit);
    final retOBp = Int32List(frameLimit);
    final retILBp = Int32List(frameLimit);
    final retFLBp = Int32List(frameLimit);
    final retDst = Int32List(frameLimit);
    final retBank = Int32List(frameLimit);

    var spFrame = 0;
    var curFnIdx = program.mainIndex;
    var curFn = functions[curFnIdx];
    var code = curFn.code;
    var iConsts = curFn.iConsts;
    var fConsts = curFn.fConsts;
    var oConsts = curFn.oConsts;
    var callSites = curFn.callSites;

    var ip = 0;
    var iBp = 0;
    var fBp = 0;
    var oBp = 0;
    var ilBp = 0;
    var flBp = 0;

    final int stepLimit = maxSteps ?? 0x3FFFFFFFFFFFFFFF;
    final int collLimit = maxCollectionLength ?? 0x3FFFFFFFFFFFFFFF;
    final int timeoutMicros = timeout?.inMicroseconds ?? 0x3FFFFFFFFFFFFFFF;
    var steps = 0;
    var timeoutTicks = 4096;

    try {
      while (true) {
        final w0 = code[ip];
        final c = code[ip + 1];
        ip += 2;
        final op = w0 & 0xFF;
        final a = (w0 >> 8) & 0x3FF;
        final b = (w0 >> 18) & 0x3FF;

        switch (op) {
          // ── Unboxed Int64 Register Ops ───────────────────────────────────
          case QudsOp.iAdd:
            iReg[iBp + a] = iReg[iBp + b] + iReg[iBp + c];
          case QudsOp.iAddImm:
            iReg[iBp + a] = iReg[iBp + b] + c;
          case QudsOp.iSub:
            iReg[iBp + a] = iReg[iBp + b] - iReg[iBp + c];
          case QudsOp.iMul:
            iReg[iBp + a] = iReg[iBp + b] * iReg[iBp + c];
          case QudsOp.iDivF:
            fReg[fBp + a] = iReg[iBp + b] / iReg[iBp + c];
          case QudsOp.iIdiv:
            iReg[iBp + a] = iReg[iBp + b] ~/ iReg[iBp + c];
          case QudsOp.iMod:
            iReg[iBp + a] = iReg[iBp + b] % iReg[iBp + c];
          case QudsOp.iNeg:
            iReg[iBp + a] = -iReg[iBp + b];
          case QudsOp.iLoadImm:
            iReg[iBp + a] = c;
          case QudsOp.iLoadK:
            iReg[iBp + a] = iConsts[c];
          case QudsOp.iMove:
            iReg[iBp + a] = iReg[iBp + b];
          case QudsOp.iJge:
            if (iReg[iBp + a] >= iReg[iBp + b]) ip = c;
          case QudsOp.iJgt:
            if (iReg[iBp + a] > iReg[iBp + b]) ip = c;
          case QudsOp.iJle:
            if (iReg[iBp + a] <= iReg[iBp + b]) ip = c;
          case QudsOp.iJlt:
            if (iReg[iBp + a] < iReg[iBp + b]) ip = c;
          case QudsOp.iJne:
            if (iReg[iBp + a] != iReg[iBp + b]) ip = c;
          case QudsOp.iJeq:
            if (iReg[iBp + a] == iReg[iBp + b]) ip = c;
          case QudsOp.iJgtK:
            if (iReg[iBp + a] > iConsts[b]) ip = c;
          case QudsOp.iJgeK:
            if (iReg[iBp + a] >= iConsts[b]) ip = c;
          case QudsOp.iJltK:
            if (iReg[iBp + a] < iConsts[b]) ip = c;
          case QudsOp.iJleK:
            if (iReg[iBp + a] <= iConsts[b]) ip = c;
          case QudsOp.iJneK:
            if (iReg[iBp + a] != iConsts[b]) ip = c;
          case QudsOp.iJeqK:
            if (iReg[iBp + a] == iConsts[b]) ip = c;

          // ── Unboxed Float64 Register Ops ─────────────────────────────────
          case QudsOp.fAdd:
            fReg[fBp + a] = fReg[fBp + b] + fReg[fBp + c];
          case QudsOp.fSub:
            fReg[fBp + a] = fReg[fBp + b] - fReg[fBp + c];
          case QudsOp.fMul:
            fReg[fBp + a] = fReg[fBp + b] * fReg[fBp + c];
          case QudsOp.fDiv:
            fReg[fBp + a] = fReg[fBp + b] / fReg[fBp + c];
          case QudsOp.fMulAdd:
            fReg[fBp + a] = fReg[fBp + a] + fReg[fBp + b] * fReg[fBp + c];
          case QudsOp.fNeg:
            fReg[fBp + a] = -fReg[fBp + b];
          case QudsOp.fLoadK:
            fReg[fBp + a] = fConsts[c];
          case QudsOp.fMove:
            fReg[fBp + a] = fReg[fBp + b];
          case QudsOp.fSqrt:
            fReg[fBp + a] = math.sqrt(fReg[fBp + b]);
          case QudsOp.fJgt:
            if (fReg[fBp + a] > fReg[fBp + b]) ip = c;
          case QudsOp.fJge:
            if (fReg[fBp + a] >= fReg[fBp + b]) ip = c;
          case QudsOp.fJlt:
            if (fReg[fBp + a] < fReg[fBp + b]) ip = c;
          case QudsOp.fJle:
            if (fReg[fBp + a] <= fReg[fBp + b]) ip = c;
          case QudsOp.fJgtK:
            if (fReg[fBp + a] > fConsts[b]) ip = c;
          case QudsOp.iToF:
            fReg[fBp + a] = iReg[iBp + b].toDouble();
          case QudsOp.fToI:
            iReg[iBp + a] = fReg[fBp + b].toInt();
          case QudsOp.fIntrinsic:
            final x = fReg[fBp + b];
            fReg[fBp + a] = switch (c) {
              _Intr.sin => math.sin(x),
              _Intr.cos => math.cos(x),
              _Intr.tan => math.tan(x),
              _Intr.abs => x.abs(),
              _Intr.exp => math.exp(x),
              _Intr.log => math.log(x),
              _Intr.floor => x.floorToDouble(),
              _Intr.ceil => x.ceilToDouble(),
              _Intr.round => x.roundToDouble(),
              _ => 0.0,
            };
          case QudsOp.fIntrinsic2:
            final x = fReg[fBp + b];
            final y = fReg[fBp + (c >> 8)];
            fReg[fBp + a] = switch (c & 0xFF) {
              _Intr.pow => math.pow(x, y).toDouble(),
              _Intr.min => x < y ? x : y,
              _Intr.max => x > y ? x : y,
              _ => 0.0,
            };

          // ── Zero-Cast Unboxed Typed Lists (`Int64List` / `Float64List`) ──
          case QudsOp.newIntList:
            final lst = _QudsIntList();
            final slot = ilBp + a;
            ilReg[slot] = lst;
            ilData[slot] = lst.data;
          case QudsOp.newFloatList:
            final lst = _QudsFloatList();
            final slot = flBp + a;
            flReg[slot] = lst;
            flData[slot] = lst.data;
          case QudsOp.newObjList:
            oReg[oBp + a] = <Object?>[];
          case QudsOp.intListAdd:
            final slot = ilBp + a;
            final lst = ilReg[slot]!;
            final len = lst.length;
            if (len >= collLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.collectionLimit,
                'Collection size (${len + 1}) exceeded maximum limit ($maxCollectionLength).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            var data = ilData[slot];
            if (len == data.length) {
              data = lst.grow();
              ilData[slot] = data;
            }
            data[len] = iReg[iBp + b];
            lst.length = len + 1;
          case QudsOp.intListGet:
            iReg[iBp + a] = ilData[ilBp + b][iReg[iBp + c]];
          case QudsOp.iAddListGet:
            iReg[iBp + a] += ilData[ilBp + b][iReg[iBp + c]];
          case QudsOp.intListSet:
            ilData[ilBp + a][iReg[iBp + b]] = iReg[iBp + c];
          case QudsOp.intListLen:
            iReg[iBp + a] = ilReg[ilBp + b]!.length;
          case QudsOp.floatListAdd:
            final slot = flBp + a;
            final lst = flReg[slot]!;
            final len = lst.length;
            if (len >= collLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.collectionLimit,
                'Collection size (${len + 1}) exceeded maximum limit ($maxCollectionLength).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            var data = flData[slot];
            if (len == data.length) {
              data = lst.grow();
              flData[slot] = data;
            }
            data[len] = fReg[fBp + b];
            lst.length = len + 1;
          case QudsOp.floatListGet:
            fReg[fBp + a] = flData[flBp + b][iReg[iBp + c]];
          case QudsOp.floatListSet:
            flData[flBp + a][iReg[iBp + b]] = fReg[fBp + c];
          case QudsOp.floatListLen:
            iReg[iBp + a] = flReg[flBp + b]!.length;
          case QudsOp.objListAdd:
            final list = oReg[oBp + a]! as List<Object?>;
            if (list.length >= collLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.collectionLimit,
                'Collection size (${list.length + 1}) exceeded maximum limit ($maxCollectionLength).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            list.add(oReg[oBp + b]);
          case QudsOp.objListGet:
            final obj = oReg[oBp + b];
            final idx = iReg[iBp + c];
            oReg[oBp + a] = obj is List ? obj[idx] : (obj as String)[idx];
          case QudsOp.objListSet:
            (oReg[oBp + a]! as List)[iReg[iBp + b]] = oReg[oBp + c];
          case QudsOp.objListLen:
            final obj = oReg[oBp + b];
            iReg[iBp + a] = obj is List ? obj.length : (obj as String).length;
          case QudsOp.intListToO:
            oReg[oBp + a] = ilReg[ilBp + b]!.toDartList();
          case QudsOp.floatListToO:
            oReg[oBp + a] = flReg[flBp + b]!.toDartList();

          // ── Control Flow & Ultra-Fast Zero-Alloc Calls ───────────────────
          case QudsOp.iIncJlt:
            final nv = iReg[iBp + a] + 1;
            iReg[iBp + a] = nv;
            if (nv < iReg[iBp + b]) {
              steps += ((ip - c) >> 1) + 2;
              if (steps > stepLimit) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.stepLimit,
                  'Bytecode VM exceeded maximum step limit ($maxSteps).',
                  SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                      file: program.file),
                );
              }
              if (--timeoutTicks <= 0) {
                timeoutTicks = 4096;
                if (stopwatch.elapsedMicroseconds > timeoutMicros) {
                  throw QudsPolicyViolationException(
                    QudsPolicyViolationKind.timeout,
                    'Bytecode VM execution timed out.',
                    SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                        file: program.file),
                  );
                }
              }
              ip = c;
            }

          case QudsOp.iIncJle:
            final nv = iReg[iBp + a] + 1;
            iReg[iBp + a] = nv;
            if (nv <= iReg[iBp + b]) {
              steps += ((ip - c) >> 1) + 2;
              if (steps > stepLimit) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.stepLimit,
                  'Bytecode VM exceeded maximum step limit ($maxSteps).',
                  SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                      file: program.file),
                );
              }
              if (--timeoutTicks <= 0) {
                timeoutTicks = 4096;
                if (stopwatch.elapsedMicroseconds > timeoutMicros) {
                  throw QudsPolicyViolationException(
                    QudsPolicyViolationKind.timeout,
                    'Bytecode VM execution timed out.',
                    SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                        file: program.file),
                  );
                }
              }
              ip = c;
            }

          case QudsOp.iIncJump:
            iReg[iBp + a] += b - 512;
            steps += ((ip - c) >> 1) + 2;
            if (steps > stepLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.stepLimit,
                'Bytecode VM exceeded maximum step limit ($maxSteps).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            if (--timeoutTicks <= 0) {
              timeoutTicks = 4096;
              if (stopwatch.elapsedMicroseconds > timeoutMicros) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.timeout,
                  'Bytecode VM execution timed out.',
                  SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                      file: program.file),
                );
              }
            }
            ip = c;

          case QudsOp.iAddJump:
            iReg[iBp + a] += iReg[iBp + b];
            steps += ((ip - c) >> 1) + 2;
            if (steps > stepLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.stepLimit,
                'Bytecode VM exceeded maximum step limit ($maxSteps).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            if (--timeoutTicks <= 0) {
              timeoutTicks = 4096;
              if (stopwatch.elapsedMicroseconds > timeoutMicros) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.timeout,
                  'Bytecode VM execution timed out.',
                  SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                      file: program.file),
                );
              }
            }
            ip = c;

          case QudsOp.jump:
            if (c < ip) {
              steps += ((ip - c) >> 1) + 1;
              if (steps > stepLimit) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.stepLimit,
                  'Bytecode VM exceeded maximum step limit ($maxSteps).',
                  SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                      file: program.file),
                );
              }
              if (--timeoutTicks <= 0) {
                timeoutTicks = 4096;
                if (stopwatch.elapsedMicroseconds > timeoutMicros) {
                  throw QudsPolicyViolationException(
                    QudsPolicyViolationKind.timeout,
                    'Bytecode VM execution timed out.',
                    SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                        file: program.file),
                  );
                }
              }
            }
            ip = c;

          // Fused pure-int self-recursive call: `dst = self(src + delta)`!
          case QudsOp.callSelfI1Sub:
            steps += 5;
            if (steps > stepLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.stepLimit,
                'Bytecode VM exceeded maximum step limit ($maxSteps).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            if (spFrame >= maxCallDepth) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.callDepth,
                'Bytecode VM exceeded maximum call depth ($maxCallDepth).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            if (--timeoutTicks <= 0) {
              timeoutTicks = 4096;
              if (stopwatch.elapsedMicroseconds > timeoutMicros) {
                throw QudsPolicyViolationException(
                  QudsPolicyViolationKind.timeout,
                  'Bytecode VM execution timed out.',
                  SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                      file: program.file),
                );
              }
            }
            final argVal = iReg[iBp + b] + (c >> 10);
            retFn[spFrame] = curFnIdx;
            retIp[spFrame] = ip;
            retDst[spFrame] = a;
            spFrame++;
            iBp += c & 0x3FF;
            iReg[iBp] = argVal;
            ip = 0;

          case QudsOp.retSelfI:
            final v = iReg[iBp + a];
            spFrame--;
            final callerIdx = retFn[spFrame];
            ip = retIp[spFrame];
            if (callerIdx == curFnIdx) {
              iBp -= c;
              iReg[iBp + retDst[spFrame]] = v;
            } else {
              iBp = retIBp[spFrame];
              fBp = retFBp[spFrame];
              oBp = retOBp[spFrame];
              ilBp = retILBp[spFrame];
              flBp = retFLBp[spFrame];
              final dst = retDst[spFrame];
              final rb = retBank[spFrame];
              if (rb == _Bank.i) {
                iReg[iBp + dst] = v;
              } else if (rb == _Bank.f) {
                fReg[fBp + dst] = v.toDouble();
              } else {
                oReg[oBp + dst] = v;
              }
              curFnIdx = callerIdx;
              curFn = functions[callerIdx];
              code = curFn.code;
              iConsts = curFn.iConsts;
              fConsts = curFn.fConsts;
              oConsts = curFn.oConsts;
              callSites = curFn.callSites;
            }

          case QudsOp.callFnI1:
            steps += 6;
            if (steps > stepLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.stepLimit,
                'Bytecode VM exceeded maximum step limit ($maxSteps).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            if (spFrame >= maxCallDepth) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.callDepth,
                'Bytecode VM exceeded maximum call depth ($maxCallDepth).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            final argVal = iReg[iBp + b];
            retFn[spFrame] = curFnIdx;
            retIp[spFrame] = ip;
            retIBp[spFrame] = iBp;
            retFBp[spFrame] = fBp;
            retOBp[spFrame] = oBp;
            retILBp[spFrame] = ilBp;
            retFLBp[spFrame] = flBp;
            retDst[spFrame] = a;
            retBank[spFrame] = _Bank.i;
            spFrame++;

            iBp += curFn.iSize;
            fBp += curFn.fSize;
            oBp += curFn.oSize;
            ilBp += curFn.ilSize;
            flBp += curFn.flSize;
            iReg[iBp] = argVal;

            if (c != curFnIdx) {
              curFnIdx = c;
              curFn = functions[c];
              code = curFn.code;
              iConsts = curFn.iConsts;
              fConsts = curFn.fConsts;
              oConsts = curFn.oConsts;
              callSites = curFn.callSites;
            }
            ip = 0;

          case QudsOp.callFn:
            steps += 8;
            if (steps > stepLimit) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.stepLimit,
                'Bytecode VM exceeded maximum step limit ($maxSteps).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            if (spFrame >= maxCallDepth) {
              throw QudsPolicyViolationException(
                QudsPolicyViolationKind.callDepth,
                'Bytecode VM exceeded maximum call depth ($maxCallDepth).',
                SourceSpan(curFn.lines[(ip - 2) >> 1], 1, 1,
                    file: program.file),
              );
            }
            final site = callSites[b];
            final callee = functions[c];
            final nextI = iBp + curFn.iSize;
            final nextF = fBp + curFn.fSize;
            final nextO = oBp + curFn.oSize;
            final nextIL = ilBp + curFn.ilSize;
            final nextFL = flBp + curFn.flSize;
            final argc = site.srcRegs.length;
            for (var k = 0; k < argc; k++) {
              final sb = site.srcBanks[k];
              final sr = site.srcRegs[k];
              final dr = site.dstRegs[k];
              if (sb == _Bank.i) {
                iReg[nextI + dr] = iReg[iBp + sr];
              } else if (sb == _Bank.f) {
                fReg[nextF + dr] = fReg[fBp + sr];
              } else if (sb == _Bank.il) {
                ilReg[nextIL + dr] = ilReg[ilBp + sr];
                ilData[nextIL + dr] = ilData[ilBp + sr];
              } else if (sb == _Bank.fl) {
                flReg[nextFL + dr] = flReg[flBp + sr];
                flData[nextFL + dr] = flData[flBp + sr];
              } else {
                oReg[nextO + dr] = oReg[oBp + sr];
              }
            }
            retFn[spFrame] = curFnIdx;
            retIp[spFrame] = ip;
            retIBp[spFrame] = iBp;
            retFBp[spFrame] = fBp;
            retOBp[spFrame] = oBp;
            retILBp[spFrame] = ilBp;
            retFLBp[spFrame] = flBp;
            retDst[spFrame] = a;
            retBank[spFrame] = site.retBank;
            spFrame++;

            iBp = nextI;
            fBp = nextF;
            oBp = nextO;
            ilBp = nextIL;
            flBp = nextFL;
            curFnIdx = c;
            curFn = callee;
            code = callee.code;
            iConsts = callee.iConsts;
            fConsts = callee.fConsts;
            oConsts = callee.oConsts;
            callSites = callee.callSites;
            ip = 0;

          case QudsOp.retI:
            final v = iReg[iBp + a];
            spFrame--;
            final callerIdx = retFn[spFrame];
            ip = retIp[spFrame];
            iBp = retIBp[spFrame];
            fBp = retFBp[spFrame];
            oBp = retOBp[spFrame];
            ilBp = retILBp[spFrame];
            flBp = retFLBp[spFrame];
            final dst = retDst[spFrame];
            final rb = retBank[spFrame];
            if (rb == _Bank.i) {
              iReg[iBp + dst] = v;
            } else if (rb == _Bank.f) {
              fReg[fBp + dst] = v.toDouble();
            } else {
              oReg[oBp + dst] = v;
            }
            if (callerIdx != curFnIdx) {
              curFnIdx = callerIdx;
              curFn = functions[callerIdx];
              code = curFn.code;
              iConsts = curFn.iConsts;
              fConsts = curFn.fConsts;
              oConsts = curFn.oConsts;
              callSites = curFn.callSites;
            }

          case QudsOp.retF:
            final v = fReg[fBp + a];
            spFrame--;
            final callerIdx = retFn[spFrame];
            ip = retIp[spFrame];
            iBp = retIBp[spFrame];
            fBp = retFBp[spFrame];
            oBp = retOBp[spFrame];
            ilBp = retILBp[spFrame];
            flBp = retFLBp[spFrame];
            final dst = retDst[spFrame];
            final rb = retBank[spFrame];
            if (rb == _Bank.f) {
              fReg[fBp + dst] = v;
            } else if (rb == _Bank.i) {
              iReg[iBp + dst] = v.toInt();
            } else {
              oReg[oBp + dst] = v;
            }
            if (callerIdx != curFnIdx) {
              curFnIdx = callerIdx;
              curFn = functions[callerIdx];
              code = curFn.code;
              iConsts = curFn.iConsts;
              fConsts = curFn.fConsts;
              oConsts = curFn.oConsts;
              callSites = curFn.callSites;
            }

          case QudsOp.retO:
            final v = oReg[oBp + a];
            spFrame--;
            final callerIdx = retFn[spFrame];
            ip = retIp[spFrame];
            iBp = retIBp[spFrame];
            fBp = retFBp[spFrame];
            oBp = retOBp[spFrame];
            ilBp = retILBp[spFrame];
            flBp = retFLBp[spFrame];
            final dst = retDst[spFrame];
            final rb = retBank[spFrame];
            if (rb == _Bank.o) {
              oReg[oBp + dst] = v;
            } else if (rb == _Bank.i) {
              iReg[iBp + dst] = (v! as num).toInt();
            } else {
              fReg[fBp + dst] = (v! as num).toDouble();
            }
            if (callerIdx != curFnIdx) {
              curFnIdx = callerIdx;
              curFn = functions[callerIdx];
              code = curFn.code;
              iConsts = curFn.iConsts;
              fConsts = curFn.fConsts;
              oConsts = curFn.oConsts;
              callSites = curFn.callSites;
            }

          case QudsOp.retVoid:
            spFrame--;
            final callerIdx = retFn[spFrame];
            ip = retIp[spFrame];
            iBp = retIBp[spFrame];
            fBp = retFBp[spFrame];
            oBp = retOBp[spFrame];
            ilBp = retILBp[spFrame];
            flBp = retFLBp[spFrame];
            final dst = retDst[spFrame];
            if (retBank[spFrame] == _Bank.o) {
              oReg[oBp + dst] = null;
            }
            if (callerIdx != curFnIdx) {
              curFnIdx = callerIdx;
              curFn = functions[callerIdx];
              code = curFn.code;
              iConsts = curFn.iConsts;
              fConsts = curFn.fConsts;
              oConsts = curFn.oConsts;
              callSites = curFn.callSites;
            }

          // ── Boxing, Globals, Dynamic Ops, Strings & IO ───────────────────
          case QudsOp.iToO:
            oReg[oBp + a] = iReg[iBp + b];
          case QudsOp.fToO:
            oReg[oBp + a] = fReg[fBp + b];
          case QudsOp.oToI:
            iReg[iBp + a] = (oReg[oBp + b]! as num).toInt();
          case QudsOp.oToF:
            fReg[fBp + a] = (oReg[oBp + b]! as num).toDouble();
          case QudsOp.oLoadK:
            oReg[oBp + a] = oConsts[c];
          case QudsOp.oMove:
            oReg[oBp + a] = oReg[oBp + b];
          case QudsOp.oLoadGlobal:
            oReg[oBp + a] = globals[c];
          case QudsOp.oStoreGlobal:
            globals[c] = oReg[oBp + a];
          case QudsOp.oJumpIfFalse:
            if (oReg[oBp + a] != true) ip = c;
          case QudsOp.oJumpIfTrue:
            if (oReg[oBp + a] == true) ip = c;
          case QudsOp.oUnaryOp:
            final v = oReg[oBp + b];
            oReg[oBp + a] = c == 0 ? -(v! as num) : !(v! as bool);
          case QudsOp.oBinOp:
            final lv = oReg[oBp + b];
            final rv = oReg[oBp + (c >> 8)];
            final kind = c & 0xFF;
            oReg[oBp + a] = switch (kind) {
              _DynBinOp.add => (lv is num && rv is num)
                  ? lv + rv
                  : '${qudsFormatValue(lv)}${qudsFormatValue(rv)}',
              _DynBinOp.sub => (lv! as num) - (rv! as num),
              _DynBinOp.mul => (lv! as num) * (rv! as num),
              _DynBinOp.div => (lv! as num) / (rv! as num),
              _DynBinOp.idiv => (lv! as num) ~/ (rv! as num),
              _DynBinOp.mod => (lv! as num) % (rv! as num),
              _DynBinOp.eq => lv == rv,
              _DynBinOp.neq => lv != rv,
              _DynBinOp.lt => (lv! as num) < (rv! as num),
              _DynBinOp.lte => (lv! as num) <= (rv! as num),
              _DynBinOp.gt => (lv! as num) > (rv! as num),
              _DynBinOp.gte => (lv! as num) >= (rv! as num),
              _ => null,
            };
          case QudsOp.iCmpToO:
            final lv = iReg[iBp + b];
            final rv = iReg[iBp + (c >> 8)];
            oReg[oBp + a] = switch (c & 0xFF) {
              _DynBinOp.eq => lv == rv,
              _DynBinOp.neq => lv != rv,
              _DynBinOp.lt => lv < rv,
              _DynBinOp.lte => lv <= rv,
              _DynBinOp.gt => lv > rv,
              _DynBinOp.gte => lv >= rv,
              _ => false,
            };
          case QudsOp.fCmpToO:
            final lv = fReg[fBp + b];
            final rv = fReg[fBp + (c >> 8)];
            oReg[oBp + a] = switch (c & 0xFF) {
              _DynBinOp.eq => lv == rv,
              _DynBinOp.neq => lv != rv,
              _DynBinOp.lt => lv < rv,
              _DynBinOp.lte => lv <= rv,
              _DynBinOp.gt => lv > rv,
              _DynBinOp.gte => lv >= rv,
              _ => false,
            };
          case QudsOp.concatStr:
            final sb = StringBuffer();
            for (var i = 0; i < c; i++) {
              sb.write(qudsFormatValue(oReg[oBp + b + i]));
            }
            oReg[oBp + a] = sb.toString();
          case QudsOp.toFixed:
            oReg[oBp + a] = fReg[fBp + b].toStringAsFixed(iReg[iBp + c]);
          case QudsOp.printI:
            final text = iReg[iBp + a].toString();
            printed.add(text);
            onPrint?.call(text);
          case QudsOp.printF:
            final text = qudsFormatValue(fReg[fBp + a]);
            printed.add(text);
            onPrint?.call(text);
          case QudsOp.printO:
            final text = qudsFormatValue(oReg[oBp + a]);
            printed.add(text);
            onPrint?.call(text);

          case QudsOp.halt:
            for (final exp in curFn.exports) {
              globals[exp.globalSlot] = switch (exp.bank) {
                _Bank.i => iReg[iBp + exp.reg],
                _Bank.f => fReg[fBp + exp.reg],
                _Bank.il => ilReg[ilBp + exp.reg]?.toDartList(),
                _Bank.fl => flReg[flBp + exp.reg]?.toDartList(),
                _ => oReg[oBp + exp.reg],
              };
            }
            final Object? finalVal = switch (curFn.resultBank) {
              _Bank.i => iReg[iBp + curFn.resultReg],
              _Bank.f => fReg[fBp + curFn.resultReg],
              _Bank.il => ilReg[ilBp + curFn.resultReg]?.toDartList(),
              _Bank.fl => flReg[flBp + curFn.resultReg]?.toDartList(),
              _Bank.o => oReg[oBp + curFn.resultReg],
              _ => null,
            };
            stopwatch.stop();
            final globalMap = <String, Object?>{};
            for (var i = 0; i < program.globalNames.length; i++) {
              globalMap[program.globalNames[i]] = globals[i];
            }
            return QudsBytecodeRunResult(
              succeeded: true,
              value: finalVal,
              printedLines: List.unmodifiable(printed),
              stepsExecuted: steps + (ip >> 1),
              elapsed: stopwatch.elapsed,
              globals: globalMap,
            );
        }
      }
    } on QudsPolicyViolationException catch (e) {
      stopwatch.stop();
      return QudsBytecodeRunResult(
        succeeded: false,
        printedLines: List.unmodifiable(printed),
        stepsExecuted: steps,
        elapsed: stopwatch.elapsed,
        error: e,
      );
    } on QudsRuntimeException catch (e) {
      stopwatch.stop();
      return QudsBytecodeRunResult(
        succeeded: false,
        printedLines: List.unmodifiable(printed),
        stepsExecuted: steps,
        elapsed: stopwatch.elapsed,
        error: e,
      );
    } catch (e) {
      stopwatch.stop();
      return QudsBytecodeRunResult(
        succeeded: false,
        printedLines: List.unmodifiable(printed),
        stepsExecuted: steps,
        elapsed: stopwatch.elapsed,
        error: QudsRuntimeException(
          'Bytecode VM runtime error: $e',
          SourceSpan(1, 1, 1, file: program.file),
        ),
      );
    }
  }

  /// Invokes a single compiled Tier-1 function [fnIndex] inside [program] with
  /// [args], executing at full unboxed 3-address register speed with zero
  /// overhead on the main dispatch loop.
  static QudsBytecodeRunResult invokeFunction(
    QudsBytecodeProgram program,
    int fnIndex,
    List<Object?> args, {
    int? maxSteps,
    int maxCallDepth = 256,
    int? maxCollectionLength,
    Duration? timeout,
    void Function(String line)? onPrint,
  }) {
    final target = program.functions[fnIndex];
    if (args.length != target.arity) {
      return QudsBytecodeRunResult(
        succeeded: false,
        error: QudsRuntimeException(
          'Function `${target.name}` expects ${target.arity} arguments, got ${args.length}.',
          SourceSpan(1, 1, 1, file: program.file),
          code: 'E500',
        ),
      );
    }

    final code = <int>[];
    final lines = <int>[];
    final iConsts = <int>[];
    final fConsts = <double>[];
    final oConsts = <Object?>[];
    final srcBanks = Int32List(args.length);
    final srcRegs = Int32List(args.length);
    var nextI = 1; // reg 0 reserved for return value
    var nextF = 1;
    var nextO = 1;

    void emit(int op, int a, int b, int c) {
      code.add((op & 0xFF) | ((a & 0x3FF) << 8) | ((b & 0x3FF) << 18));
      code.add(c);
      lines.add(1);
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final expectedBank = target.paramBanks[i];
      if (expectedBank == _Bank.i) {
        if (arg is! int) {
          return QudsBytecodeRunResult(
            succeeded: false,
            error: QudsRuntimeException(
              'Expected `int` for argument ${i + 1} of `${target.name}`.',
              SourceSpan(1, 1, 1, file: program.file),
            ),
          );
        }
        final reg = nextI++;
        final kIdx = iConsts.length;
        iConsts.add(arg);
        emit(QudsOp.iLoadK, reg, kIdx, 0);
        srcBanks[i] = _Bank.i;
        srcRegs[i] = reg;
      } else if (expectedBank == _Bank.f) {
        if (arg is! num) {
          return QudsBytecodeRunResult(
            succeeded: false,
            error: QudsRuntimeException(
              'Expected `double` for argument ${i + 1} of `${target.name}`.',
              SourceSpan(1, 1, 1, file: program.file),
            ),
          );
        }
        final reg = nextF++;
        final kIdx = fConsts.length;
        fConsts.add(arg.toDouble());
        emit(QudsOp.fLoadK, reg, kIdx, 0);
        srcBanks[i] = _Bank.f;
        srcRegs[i] = reg;
      } else {
        final reg = nextO++;
        final kIdx = oConsts.length;
        oConsts.add(arg);
        emit(QudsOp.oLoadK, reg, kIdx, 0);
        srcBanks[i] = _Bank.o;
        srcRegs[i] = reg;
      }
    }

    final site = _CallSite(
      srcBanks: srcBanks,
      srcRegs: srcRegs,
      dstBanks: target.paramBanks,
      dstRegs: target.paramRegs,
      retBank: target.returnBank,
    );
    emit(QudsOp.callFn, 0, 0, fnIndex);
    emit(QudsOp.halt, 0, 0, 0);

    final trampoline = QudsBytecodeFunction(
      name: '<invoke:${target.name}>',
      arity: 0,
      iSize: nextI + 1,
      fSize: nextF + 1,
      oSize: nextO + 1,
      ilSize: 1,
      flSize: 1,
      paramBanks: Int32List(0),
      paramRegs: Int32List(0),
      returnBank: target.returnBank,
      code: Int32List.fromList(code),
      lines: Int32List.fromList(lines),
      iConsts: Int64List.fromList(iConsts),
      fConsts: Float64List.fromList(fConsts),
      oConsts: oConsts,
      callSites: [site],
      resultBank: target.returnBank,
      resultReg: 0,
    );

    final wrapperFns = [...program.functions, trampoline];
    final wrapper = QudsBytecodeProgram(
      functions: wrapperFns,
      mainIndex: wrapperFns.length - 1,
      globalNames: program.globalNames,
      file: program.file,
      globalMutable: program.globalMutable,
    );
    return run(
      wrapper,
      maxSteps: maxSteps,
      maxCallDepth: maxCallDepth,
      maxCollectionLength: maxCollectionLength,
      timeout: timeout,
      onPrint: onPrint,
    );
  }
}
