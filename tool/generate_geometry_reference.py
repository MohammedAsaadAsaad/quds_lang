"""Frozen Quds geometry references using Python Fraction and gift wrapping."""
from fractions import Fraction as F
from pathlib import Path
import math
import random

rng = random.Random(77391)
checks=[]
def q(point): return tuple(F.from_float(float(x)) for x in point)
def v(point): return f'Vec2(x: {float(point[0])!r}, y: {float(point[1])!r})'
def vertices(points): return '['+', '.join(map(v,points))+']'
def sign(value): return (value>0)-(value<0)
def orient(a,b,c):
    a,b,c=map(q,[a,b,c])
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def on(a,b,p):
    return orient(a,b,p)==0 and all(min(a[i],b[i])<=p[i]<=max(a[i],b[i]) for i in [0,1])
def intersects(a,b,c,d):
    aa,bb,cc,dd=map(q,[a,b,c,d])
    r=(bb[0]-aa[0],bb[1]-aa[1]);s=(dd[0]-cc[0],dd[1]-cc[1])
    cross=lambda x,y:x[0]*y[1]-x[1]*y[0]
    denominator=cross(r,s)
    if denominator:
        delta=(cc[0]-aa[0],cc[1]-aa[1])
        t=cross(delta,s)/denominator;u=cross(delta,r)/denominator
        return 0<=t<=1 and 0<=u<=1
    return on(a,b,c) or on(a,b,d) or on(c,d,a) or on(c,d,b)
def hull(points):
    unique=sorted(set(points))
    if len(unique)<2:return unique
    output=[];current=unique[0]
    while True:
        output.append(current)
        candidate=next(p for p in unique if p!=current)
        for point in unique:
            turn=orient(current,candidate,point)
            distance=lambda p:sum((q(p)[i]-q(current)[i])**2 for i in [0,1])
            if turn<0 or (turn==0 and distance(point)>distance(candidate)):
                candidate=point
        current=candidate
        if current==output[0]:return output
        assert len(output)<=len(unique)
def area(points):
    total=F(0)
    for a,b in zip(points,points[1:]+points[:1]):
        aa,bb=map(q,[a,b]);total+=aa[0]*bb[1]-aa[1]*bb[0]
    return total/2
def inside(point,points,boundary):
    if any(on(a,b,point) for a,b in zip(points,points[1:]+points[:1])):return boundary
    pp=q(point);winding=0
    for a,b in zip(points,points[1:]+points[:1]):
        aa,bb=q(a),q(b)
        if (aa[1]<=pp[1]<bb[1]) or (bb[1]<=pp[1]<aa[1]):
            crossing=aa[0]+(pp[1]-aa[1])*(bb[0]-aa[0])/(bb[1]-aa[1])
            if crossing>pp[0]:winding+=1 if bb[1]>aa[1] else -1
    return winding!=0

def case(expression,expected):
    if isinstance(expected,bool):expected=str(expected).lower()
    checks.append(f'  _geomCase(counter, {expression}, {expected})')
def rational(expression,expected):
    checks.append(f'  _geomRational(counter, {expression}, "{expected.numerator}", "{expected.denominator}")')
for x in [0.,-0.,5e-324,-5e-324,1e-320,-1e-320,2.2250738585072014e-308,
          .1,.2,.3,-.1,math.pi,math.sqrt(2),1e-150,-1e150,1e308,-1e308,math.nextafter(math.inf,0)]:
    rational(f'binaryFraction({x!r})',F.from_float(x))
fixed=[[(0.,0.),(1.,0.),(0.,1.)],[(1e308,1e308),(-1e308,1e308),(0.,-1e308)],
       [(0.,0.),(1e-300,0.),(0.,1e-300)],[(0.,0.),(1.,1.),(2.,2.)]]
for points in fixed:
    case('orientation2D('+', '.join(map(v,points))+')',sign(orient(*points)))
for _ in range(240):
    scale=rng.choice([1e-300,1e-150,1e-5,1.,1e50,1e150,1e300])
    points=[(rng.randrange(-5,6)*scale,rng.randrange(-5,6)*scale) for _ in range(3)]
    case('orientation2D('+', '.join(map(v,points))+')',sign(orient(*points)))
for exponent in [-300,-150,-20,0,50,150,300]:
    scale=10.**exponent
    for direction in [math.inf,-math.inf]:
        points=[(0.,0.),(scale,scale),(2*scale,math.nextafter(2*scale,direction))]
        case('orientation2D('+', '.join(map(v,points))+')',sign(orient(*points)))
for _ in range(160):
    scale=rng.choice([1e-300,1e-150,1.,1e150,1e300])
    points=[(rng.randrange(-4,5)*scale,rng.randrange(-4,5)*scale) for _ in range(4)]
    case('segmentsIntersect('+', '.join(map(v,points))+')',intersects(*points))
sets=[[],[(0.,0.)],[(0.,0.),(1.,1.),(2.,2.),(1.,1.)],
      [(0.,0.),(1.,0.),(1.,1.),(0.,1.),(.5,.5)],
      [(1e308,1e308),(-1e308,1e308),(-1e308,-1e308),(1e308,-1e308)]]
for _ in range(65):
    scale=rng.choice([1e-300,1e-100,1.,1e100,1e300])
    sets.append([(rng.randrange(-8,9)*scale,rng.randrange(-8,9)*scale) for _ in range(rng.randrange(16))])
for points in sets:
    checks.append(f'  _geomHull(counter, {vertices(points)}, {vertices(hull(points))})')
    rational(f'polygonSignedAreaExact({vertices(points)})',area(points))
    if points:
        query=points[0]
        for boundary in [True,False]:
            case(f'pointInPolygon({v(query)}, {vertices(points)}, includeBoundary: {str(boundary).lower()})',inside(query,points,boundary))
for points in [ [(0.,0.),(2.,0.),(2.,2.),(0.,2.)],
                [(0.,0.),(2.,0.),(2.,2.),(1.,1.),(0.,2.)],
                [(0.,0.),(2.,0.),(2.,2.),(0.,2.)]*2 ]:
    for query in [(-1.,0.),(0.,0.),(1.,1.),(1.5,.5),(3.,1.),(2.,1.)]:
        for boundary in [True,False]:
            case(f'pointInPolygon({v(query)}, {vertices(points)}, includeBoundary: {str(boundary).lower()})',inside(query,points,boundary))
header='''# Generated from Python Fraction.from_float, parametric segments and Jarvis hulls.
use quds:math

class _GeomCount:
  var value: int = 0

_geomCase(counter: _GeomCount, actual: Object?, expected: Object?):
  counter.value += 1
  expect(actual, equals(expected))

_geomRational(counter: _GeomCount, actual: BigFraction, top: String, bottom: String):
  counter.value += 1
  expect(actual.numerator.toString(), top)
  expect(actual.denominator.toString(), bottom)

_geomHull(counter: _GeomCount, points: List<Vec2>, expected: List<Vec2>):
  counter.value += 1
  snapshot = points.toList()
  expect(convexHull(points), equals(expected))
  expect(points, equals(snapshot))

test "exact geometry against independent Quds reference cases":
  counter = _GeomCount()
'''
Path('test/math_geometry_reference.quds').write_text(header+'\n'.join(checks)+
    f'\n  expect(counter.value, {len(checks)})\n  print "QUDS GEOMETRY CHECKS={len(checks)} FAILURES=0"\n')
print(f'Quds geometry references: {len(checks)}')
