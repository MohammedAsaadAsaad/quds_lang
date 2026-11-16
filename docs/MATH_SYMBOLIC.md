# Exact symbolic trees: calculus and domain-preserving simplification

`quds:math::symbolic` contains a mathematical data AST, independent of the Quds
language parser. It can also be imported through `use quds:math`.
The numeric coefficients are exact `BigFraction` values; no decimal text or
binary64 conversion is involved. The public function count remains 380.

## Supported operations

`exprNumber`, `exprSymbol`, `exprAdd`, `exprSubtract`, `exprMultiply`,
`exprDivide`, `exprPower`, `exprSqrt` and `exprSin` construct `Expr` nodes.
`exprText` renders the tree, not a canonical mathematical equivalence class.
There is no public numerical expression evaluator or substitution engine here.
The constructors do not introduce language syntax or evaluate a square root.

`simplifyExpr` recursively folds rational arithmetic, removes additive zero and
multiplicative one, and folds an integer power of rational constants when its
absolute exponent is at most 16. Constant powers use the convention `a^0 = 1`,
including `0^0`. A negative power of zero and rational division by zero throw.
A larger constant exponent throws `symbolic power exceeds the work limit`.
Noninteger powers, square roots and sine remain formal nodes.

Multiplication by zero collapses only after a conservative proof that the
other operand is defined for every finite real assignment of its symbols:

- Numbers and symbols are total. Sums, differences and products of total
  expressions are total, as is sine of a total expression.
- Division is proved total only for a total numerator and a known nonzero
  rational constant denominator.
- Nonnegative integer powers of total expressions are total.
- Square roots are proved total only for a known nonnegative rational constant.
- Other or unproved forms retain their domain by staying in the tree.

Thus `0*x` simplifies to zero, whereas `0*(1/x)`, `(x/x)*0`, `0*sqrt(x)` and
`0*x^-1` retain their potentially undefined factors. Constant singularities
are checked during recursive folding before multiplication can discard them.
Neither `x/x` nor `sqrt(x*x)` is rewritten. This proof is deliberately incomplete:
for example it does not infer that `x*x+1` is a nonzero denominator.

`deriveExpr(tree, variable)` supports rational constants, symbols, sums,
differences, products and integer powers whose inner derivative is supported.
The derivative of a zero power is zero only for a proved-total base. Otherwise
it throws `symbolic derivative is not supported`, rather than removing a domain
condition or introducing a spurious reciprocal at zero. Direct sine,
square-root and division derivatives remain unsupported and throw the same
string. This is not a general symbolic differentiator with assumptions.

`integratePolynomial(tree, variable)` expands exact coefficients of one
polynomial, with an intermediate degree budget of 16, and omits the constant
of integration. An antiderivative may have degree 17. Unsupported symbols,
negative/noninteger powers and nonpolynomial operations throw
`symbolic integral is not supported`. Exceeding the intermediate coefficient
budget throws `symbolic polynomial exceeds the work limit`; cancellation
outside that budget is not promised. The zero polynomial integrates to zero.

The AST APIs expect well-formed, acyclic trees produced by the factories,
stable during an operation. `Expr.arguments` is an ordinary mutable list; the
value class does not imply deep immutability, cycle detection, or an untrusted
input validation boundary. Simplification can share input nodes when an
identity returns an existing operand. There is no broad CAS, branch analysis,
assumption solver, equivalence checker or symbolic integration of arbitrary
functions in this delivery.

## Import scope and compiler regressions

`use quds:math::symbolic as symbolic` validates `Expr` in its own library:
its `BigFraction` field type need not be separately exposed to the caller.
A caller's distinct class named `BigFraction` stays distinct. Inferred field
types retain the SDK type identity and use private backend imports when needed;
this does not make `BigFraction` or SDK private classes source-visible.
Private SDK metadata also has library-specific keys, so the caller may declare
its own private class `_PhaseState` without colliding with a compiler detail.
Constructor checks reject an unrelated caller class in a sibling-typed field.

Argument analysis now reuses the results of one successful parameter check.
Only single-signature calls reuse the initial candidate trial; competing
overloads still perform their selected contextual check. This removes repeated
recursive work on deeply nested regular calls while keeping argument type,
label, default, variadic and overload checks. Runtime evaluation order is
unchanged.

## Primary tests

```sh
dart run bin/quds.dart test test/math_symbolic.quds
dart run bin/quds.dart test test/math_symbolic_imports.quds
dart run bin/quds.dart test test/math_symbolic_reference.quds
```

The handwritten suites cover singular domains, preserved guards, zero powers,
zero/cancelling polynomials, safe identities, section imports, sibling nominal
types, private name isolation, and exactly-once execution of twenty nested
calls. A compiler regression checks forty nested single-signature calls.

The frozen references use independently computed Python `Fraction` formulas
for polynomial values, derivatives and antiderivatives. The Quds oracle only
evaluates the generated trees; it never differentiates or integrates them.
**1475 checks on 59 polynomials** compare the input and simplified tree,
derivative, integral, and the
derivative of the integral at exact rational points, including zero. Dense degree-9, degree-12 and degree-16 polynomials
cover the documented upper-degree contract. Explicit integer powers up to 16
are accepted; the previous exponent-8 restriction contradicted that contract
and has been corrected.
Generation uses only the Python standard library and a fixed seed:

```sh
python3 tool/generate_symbolic_reference.py
```

Supplemental JavaScript checks cover the domain-preserving product and the
zero-power derivative. Final command results are in [VALIDATION.md](VALIDATION.md).
