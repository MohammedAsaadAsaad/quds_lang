"""Frozen Quds AD references from mpmath, including binary64 extreme scales."""
from pathlib import Path
import math
import mpmath as mp

cases = []
def record(expr, value, slope):
    value, slope = float(value), float(slope)
    if math.isfinite(value) and math.isfinite(slope):
        cases.append((expr, value, slope))
def source(x, seed):
    return f'Dual(value: {float(x)!r}, tangent: {float(seed)!r})'

# 400 digits preserve exact binary64 arguments even for trig reduction at 1e150.
with mp.workdps(400):
    for name, f, derivative, points in [
        ('sin', mp.sin, mp.cos, [-3., -1., -1e-150, 0., .1, 1., 3., 1e150]),
        ('cos', mp.cos, lambda x:-mp.sin(x), [-3., -1., -1e-150, 0., .1, 1., 3., 1e150]),
        ('tan', mp.tan, lambda x:1/mp.cos(x)**2, [-3., -1., -1e-150, 0., .1, 1., 3., 1e150]),
        ('atan', mp.atan, lambda x:1/(1+x*x), [-3., -1., -1e-150, 0., .1, 1., 3., 1e150, 1e200]),
        ('asin', mp.asin, lambda x:1/mp.sqrt(1-x*x), [-.999999, -.5, 0., .5, .999999]),
        ('acos', mp.acos, lambda x:-1/mp.sqrt(1-x*x), [-.999999, -.5, 0., .5, .999999]),
        ('exp', mp.exp, mp.exp, [-700., -3., 0., 3., 700.]),
        ('ln', mp.log, lambda x:1/x, [1e-300,1e-150,.1,1.,3.,1e150,1e300]),
        ('sqrt', mp.sqrt, lambda x:1/(2*mp.sqrt(x)), [1e-300,1e-150,.1,1.,3.,1e150,1e300]),
    ]:
        for x in points:
            for seed in [-2., 0., 1e-150, 1., 1e150]:
                xx, ss = mp.mpf(x), mp.mpf(seed)
                record(f'{source(x,seed)}.{name}()', f(xx), derivative(xx)*ss)
    for x in [-3.,-1.,-1e-150,1e-150,.2,1.,3.,1e150,1e200]:
        for exponent in [-3.,-1.,0.,1.,2.,3.,.5,1.5]:
            if x < 0 and exponent != math.trunc(exponent):
                continue
            for seed in [0.,1e-150,1.,1e150,1e308]:
                xx, nn, ss = mp.mpf(x), mp.mpf(exponent), mp.mpf(seed)
                record(f'{source(x,seed)}.pow({exponent!r})', xx**nn,
                       nn*xx**(nn-1)*ss if exponent else 0)
    for x,dx,y,dy in [
        (1e-200,0.,1e200,1e308), (1e308,0.,.1,1e-308),
        (1e9,0.,1e-300,5e-324), (5e-324,0.,.7,1e308), (5e-324,0.,.1,1e308), (1.,2.,3.,4.), (1e-150,1.,1e-150,1.),
    ]:
        xx, ddx, yy, ddy = map(mp.mpf, [x,dx,y,dy])
        record(f'({source(x,dx)} / {source(y,dy)})', xx/yy, (ddx*yy-xx*ddy)/(yy*yy))
    # A very large even integer exponent must retain odd derivative parity.
    exponent = 18014398509481984.
    record(f'{source(-1.,1.)}.pow({exponent!r})', 1, -mp.mpf(exponent))

header='''# Generated from independent mpmath 400-digit values/analytic derivatives.
# Run: quds test test/math_autodiff_reference.quds
use quds:math

class _ADCount:
  var value: int = 0

_adNear(actual: double, expected: double, description: String):
  expect(actual.isFinite, true, reason: description)
  expect((actual - expected).abs <= 1.0e-10 * expected.abs + 1.5e-323, true, reason: description)

_adReference(counter: _ADCount, index: int, actual: Dual, value: double, tangent: double):
  counter.value += 1
  _adNear(actual.value, value, "value case {index}")
  _adNear(actual.tangent, tangent, "derivative case {index}")

test "automatic differentiation against independent analytic references":
  counter = _ADCount()
'''
body=''.join(f'  _adReference(counter, {i}, {e}, {v!r}, {d!r})\n' for i,(e,v,d) in enumerate(cases,1))
Path('test/math_autodiff_reference.quds').write_text(header+body+
    f'  expect(counter.value, {len(cases)})\n  print "QUDS AD CHECKS={len(cases)} FAILURES=0"\n')
print(f'Quds AD references: {len(cases)}')
