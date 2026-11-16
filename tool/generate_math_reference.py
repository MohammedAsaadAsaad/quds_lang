# Regenerate shared references for primary Quds suites and supplemental Dart checks.
# Running the committed Quds suites does not require Python or SciPy.
import math,json,itertools
import numpy as np
from scipy import special as sp, stats as st
from pathlib import Path
cases=[]
quds_cases=[]
def lit(v):
 if isinstance(v,str):return v
 if isinstance(v,(list,tuple,np.ndarray)):return '['+', '.join(lit(x) for x in v)+']'
 if isinstance(v,(int,np.integer)):return str(v)
 if not math.isfinite(float(v)):return 'double.infinity' if v>0 else '-double.infinity' if v<0 else 'double.nan'
 return repr(float(v))
def case(expr,expected,rtol=1e-7,atol=1e-11):
 if not math.isnan(float(expected)):cases.append((expr,float(expected),rtol,atol))
def quds_lit(value):
 if isinstance(value,str):
  # Explicit callback spellings, not a Dart-to-Quds text transpiler.
  return {
   '(double x) => x*x':'(x: double) -> x*x',
   '(double x) => x*x*x':'(x: double) -> x*x*x',
   '(double x)=>x*x*x*x':'(x: double) -> x*x*x*x',
  }[value]
 return lit(value)
def add(name,args,expected,rtol=1e-7,atol=1e-11):
 case(f'm.{name}('+', '.join(lit(x) for x in args)+')',expected,rtol,atol)
 if not math.isnan(float(expected)):
  expression=f'm.{name}('+', '.join(quds_lit(x) for x in args)+')'
  quds_cases.append((expression,float(expected),rtol,atol))
for name,ref,xs in [
 ('sinh',math.sinh,[-700,-20,-1,-1e-10,0,1e-10,1,20,700]),('cosh',math.cosh,[-700,-20,-1,0,1,20,700]),
 ('tanh',math.tanh,[-100,-20,-1,-1e-10,0,1e-10,1,20,100]),('asinh',math.asinh,[-1e200,-1,-1e-10,0,1e-10,1,1e200]),
 ('acosh',math.acosh,[1,1+1e-12,1.1,2,1e200]),('atanh',math.atanh,[-.99,-.5,-1e-12,0,1e-12,.5,.99]),
 ('log1p',math.log1p,[-.999999,-.5,-1e-12,0,1e-12,1,1e200]),('expm1',np.expm1,[-1000,-100,-1,-1e-12,0,1e-12,1,100,1000]),
 ('cbrt',np.cbrt,[-1e300,-8,-1e-200,0,1e-200,8,1e300]),('erf',sp.erf,[-10,-5,-1,0,.1,1,5,10]),('erfc',sp.erfc,[-5,-1,0,1,5,10,20]),
 ('gamma',sp.gamma,[-5.5,-2.5,-1.5,-.5,.1,.5,1,2,10,50,170]),('logGamma',sp.gammaln,[-5.5,-2.5,-1.5,-.5,.1,.5,1,2,10,50,170]),
 ('digamma',sp.digamma,[.1,.5,1,2,10,100]),('inverseErf',sp.erfinv,[-.99,-.5,0,.5,.99]),
 ('zeta',lambda x:sp.zeta(x,1),[1.01,1.1,1.5,2,3,10,50]),('lambertW',lambda x:sp.lambertw(x).real,[-1/math.e,-.36,-.1,0,1e-12,.1,1,math.e,10,1e20,1e200]),
 ('airyAi',lambda x:sp.airy(x)[0],[-12,-8,-2,0,2,5,8,10,12]),('airyBi',lambda x:sp.airy(x)[2],[-12,-8,-2,0,2,5,8,10,12]),
 ('ellipticK',lambda k:sp.ellipk(k*k),[0,.1,.5,.9,.99,.999999]),('ellipticE',lambda k:sp.ellipe(k*k),[0,.1,.5,.9,.99,.999999,1]),
 ('besselY0',sp.y0,[.1,1,5,10,20,50])]:
 for x in xs:
  with np.errstate(all='ignore'):add(name,[float(x)],ref(x),2e-6 if name in ['erf','erfc','besselY0'] else 1e-7,1.6e-7 if name in ['erf','erfc'] else 1e-11)
for name,ref in [('besselJ',sp.jv),('besselY',sp.yv),('besselI',sp.iv),('besselK',sp.kv)]:
 for n,x in itertools.product([0,1,2,5,10],[.1,1.,5.,10.,20.,50.]):add(name,[n,x],ref(n,x),2e-6)
for nu,x in itertools.product([-.5,-1.5,.5,1.5,2.3],[.1,1.,5.,20.,50.]):add('besselJReal',[nu,x],sp.jv(nu,x),2e-6)
for n,x in itertools.product([0,1,2,5,10],[0.,.1,1.,3.]):
 for name,ref in [('legendre',sp.eval_legendre),('hermite',sp.eval_hermite),('laguerre',sp.eval_laguerre)]:add(name,[n,x],ref(n,x))
for a,b,z in itertools.product([.5,1.,2.],[.5,2.],[-.99,-.5,.5,.9,.99]):add('hypergeometric',[a,b,3.,z],sp.hyp2f1(a,b,3,z),1e-7)
for a,b,x in itertools.product([.1,.5,1.,2.,10.,100.],[.5,2.,10.],[1e-8,.01,.5,.99,1-1e-8]):
 add('incompleteBeta',[a,b,x],sp.betainc(a,b,x))
for a,x in itertools.product([.1,.5,1.,2.,10.,100.,1000.],[0.,.1,1.,10.,100.,1000.]):add('lowerGamma',[a,x],sp.gammainc(a,x))
for x in [-12.,-8.,-3.,0.,3.,8.,12.]:
 add('normalCdf',[x,0.,1.],st.norm.cdf(x),1e-6,1e-12);add('normalPdf',[x,0.,1.],st.norm.pdf(x))
for p in [1e-8,1e-4,.01,.5,.99,1-1e-8]:add('normalQuantile',[p,0.,1.],st.norm.ppf(p),1e-6)
for df,x in itertools.product([.5,1.,2.,5.,30.,100.],[-10.,-1.,0.,1.,10.]):
 add('studentCdf',[x,df],st.t.cdf(x,df));add('studentPdf',[x,df],st.t.pdf(x,df))
for df,p in itertools.product([1.,5.,30.],[.01,.5,.99]):add('studentQuantile',[p,df],st.t.ppf(p,df),1e-6)
for df,x in itertools.product([.5,1.,2.,5.,30.],[.01,1.,10.,50.]):
 add('chiSquarePdf',[x,df],st.chi2.pdf(x,df));add('chiSquareCdf',[x,df],st.chi2.cdf(x,df))
for df,p in itertools.product([.5,2.,30.],[.01,.5,.99]):add('chiSquareQuantile',[p,df],st.chi2.ppf(p,df),1e-6)
for a,b,x in itertools.product([1.,2.,10.],[1.,5.,30.],[.01,1.,10.]):
 add('fisherPdf',[x,a,b],st.f.pdf(x,a,b));add('fisherCdf',[x,a,b],st.f.cdf(x,a,b))
for name,ref in [('binomialPmf',st.binom.pmf),('binomialCdf',st.binom.cdf)]:
 for n,p in itertools.product([0,1,20,100,1000],[0.,.01,.5,.99,1.]):
  for k in set([0,n//2,n]):add(name,[k,n,p],ref(k,n,p))
for name,ref in [('poissonPmf',st.poisson.pmf),('poissonCdf',st.poisson.cdf)]:
 for lam in [0.,1.,30.,100.,1000.]:
  for k in set([0,int(lam),int(lam+2*math.sqrt(lam))]):add(name,[k,lam],ref(k,lam))
for name,ref in [('gammaPdf',st.gamma.pdf),('gammaCdf',st.gamma.cdf)]:
 for a,x in itertools.product([.5,1.,2.,10.],[.01,1.,10.,100.]):add(name,[x,a,2.],ref(x,a,scale=2))
for name,ref in [('betaPdf',st.beta.pdf),('betaCdf',st.beta.cdf)]:
 for a,b,x in itertools.product([.5,1.,2.,10.],[.5,1.,2.],[0.,.01,.5,.99,1.]):
  if math.isfinite(ref(x,a,b)):add(name,[x,a,b],ref(x,a,b))
for k,N,K,n in [(2,5,3,2),(20,100,50,40),(25,1000,500,50),(0,100,10,10)]:
 add('hypergeometricPmf',[k,N,K,n],st.hypergeom.pmf(k,N,K,n));add('hypergeometricCdf',[k,N,K,n],st.hypergeom.cdf(k,N,K,n))
for r,p,k in itertools.product([1,5,50],[.1,.5,1.],[0,5,100]):
 add('negativeBinomialPmf',[k,r,p],st.nbinom.pmf(k,r,p));add('negativeBinomialCdf',[k,r,p],st.nbinom.cdf(k,r,p))
# Scalar numerical algorithms compared with analytic polynomials/exponentials.
for name,expr,ref in [('integrate','(double x) => x*x',1/3),('simpson','(double x) => x*x',1/3),('gaussLegendre','(double x) => x*x',1/3)]:
 add(name,[expr,0.,1.,100 if name!='gaussLegendre' else 5],ref,1e-4)
for n in [10,100,1000]:
 add('derivative',['(double x) => x*x*x',float(n),1e-3],3*n*n,1e-6)
 add('secondDerivative',['(double x) => x*x',float(n)],2.,1e-5)
# Executed by the reference generator after defining case/add.
# Previously uncovered elementary functions and summary statistics.
for expr,value in {
 'm.tau()':2*math.pi, 'm.phi()':(1+math.sqrt(5))/2,'m.radians(180.0)':math.pi,
 'm.wrapRadians(5.0*math.pi)':math.pi,'m.lerp(2.0,6.0,0.25)':3.,'m.inverseLerp(2.0,6.0,3.0)':.25,
 'm.remap(3.0,2.0,6.0,10.0,30.0)':15.,'m.signOf(-1.0)':-1,'m.fractional(-1.25)':.75,
 'm.log2(8.0)':3.,'m.log10(1000.0)':3.,'m.decimalScale(3)':1000.,'m.roundTo(1.235,2)':1.24,
 'm.floorTo(-1.231,2)':-1.24,'m.ceilTo(-1.239,2)':-1.23,'m.smoothstep(0.0,1.0,0.5)':.5,
 'm.lerpAngle(0.0,1.0,0.5)':.5,'m.sinc(0.0)':1.,'m.logit(0.5)':0.,'m.ipow(-2,5)':-32,
 'm.interval(3.0,1.0).low':1., 'm.sumOf([1.0,2.0,3.0])':6.,'m.product([2.0,3.0,4.0])':24.,
 'm.minimum([3.0,1.0,2.0])':1.,'m.maximum([3.0,1.0,2.0])':3.,'m.sampleRange([3.0,1.0,2.0])':2.,
 'm.variance([1.0,2.0,3.0])':1.,'m.populationVariance([1.0,2.0,3.0])':2/3,
 'm.populationStddev([1.0,2.0,3.0])':math.sqrt(2/3),'m.percentile([1.0,2.0,3.0,4.0],25.0)':1.75,
 'm.quantile([1.0,2.0,3.0,4.0],0.25)':1.75,'m.covariance([1.0,2.0,3.0],[2.0,4.0,6.0])':2.,
 'm.zScores([1.0,2.0,3.0])[0]':-math.sqrt(1.5),'m.trapezoid([0.0,1.0,2.0],1.0)':2.,
 'm.fitResiduals([[1.0,0.0],[1.0,1.0],[1.0,2.0]],[1.0,3.0,5.0])[0]':0.,
 'm.fitRSquared([[1.0,0.0],[1.0,1.0],[1.0,2.0]],[1.0,3.0,5.0])':1.,
 'm.rungeKuttaAdaptiveSystem((double x,List<double> y)=>[y[0]],0.0,[1.0],1.0,1e-9)[0]':math.e,
 'm.exponentialQuantile(0.5,2.0)':math.log(2)/2,'m.weibullPdf(1.0,2.0,3.0)':st.weibull_min.pdf(1,2,scale=3),
 'm.weibullQuantile(0.5,2.0,3.0)':st.weibull_min.ppf(.5,2,scale=3),'m.geometricCdf(3,0.3)':st.geom.cdf(4,.3),
 'm.gammaQuantile(0.5,3.0,2.0)':st.gamma.ppf(.5,3,scale=2), 'm.betaQuantile(0.3,2.0,5.0)':st.beta.ppf(.3,2,5),
 'm.lognormalPdf(2.0,0.2,0.7)':st.lognorm.pdf(2,.7,scale=math.exp(.2)),
 'm.lognormalQuantile(0.3,0.2,0.7)':st.lognorm.ppf(.3,.7,scale=math.exp(.2)),
 'm.cauchyPdf(1.0,0.2,0.7)':st.cauchy.pdf(1,loc=.2,scale=.7),'m.cauchyQuantile(0.3,0.2,0.7)':st.cauchy.ppf(.3,loc=.2,scale=.7),
 'm.hamming(1)[0]':1.,'m.blackman(1)[0]':1.,'m.hann(1)[0]':1.,
 'm.mean([1e308,1e308])':1e308,'m.median([1e308,1e308])':1e308,
 'm.populationVariance([-1e154,1e154])':1e308,
 'm.lineFit([1000000000000.0,1000000000001.0,1000000000002.0],[1.0,3.0,5.0]).slope':2.,
 'm.vectorLength([1e200,1e200])':math.sqrt(2)*1e200,
 'm.Complex(real:1e200,imag:1e200).reciprocal().real':.5e-200,
 '(m.Complex(real:1e200,imag:1e200)/m.Complex(real:1e200,imag:1e200)).real':1.,
 'm.complexMatmul([[m.Complex(real:1.0,imag:2.0)]],[[m.Complex(real:3.0,imag:-1.0)]])[0][0].imag':5.,
 'm.chineseRemainder([1,1],[4,2])':1.,'m.chineseRemainder([0,0],[1,1])':0.,
 'm.gcd((-9223372036854775807-1),3)':1,
 'm.quadraticRoots(1e-100,-3e-100,2e-100)[0].real':1.,
 'm.quadraticRoots(1.0,1e8,1.0)[1].real':-1e-8,
 'm.polyRoots([-1e-100,1e-100])[0].real':1.,
}.items():case(expr,value)
case('(m.approximately(1.0,1.0+1e-10,1e-9)?1:0)',1,0,0)
# Exact integer comparisons: no float conversion of integer oracles.
import random
rng=random.Random(239)
for n in range(300):
 prime=n>=2 and all(n%d for d in range(2,math.isqrt(n)+1))
 case(f'(m.isProbablePrime({n})=={str(prime).lower()}?1:0)',1,0,0)
for _ in range(100):
 a=rng.randrange(-2**63,2**63);b=rng.randrange(0,1000);mod=rng.randrange(1,2**63)
 case(f'(m.modPow({a},{b},{mod})=={pow(a,b,mod)}?1:0)',1,0,0)
 if math.gcd(a,mod)==1 and mod>1:case(f'(m.modInverse({a},{mod})=={pow(a,-1,mod)}?1:0)',1,0,0)
for n,k in [(20,10),(60,30),(66,33)]:case(f'(m.combinations({n},{k})=={math.comb(n,k)}?1:0)',1,0,0)
# Domain/overflow failures, not silent wrapped results.
for expr in ['m.factorial(21)','m.fibonacci(93)','m.ipow(2,63)','m.nextPrime(9223372036854775807)',
 'm.lcm(9223372036854775807,2)','m.combinations(67,33)','m.interp(1.5,[2.0,1.0],[1.0,2.0])',
 'm.heat([0.0,1.0,0.0],-1.0,1.0,1.0,1)', 'm.hypergeometric(1.0,1.0,0.0,0.5)']:
 case('rejects(() => '+expr+')',1,0,0)
# Every matrix scale is compared after normalizing the result, so tiny inputs
# cannot pass by hiding behind the absolute tolerance.
np_rng=np.random.default_rng(713)
for msize,nsize in [(2,2),(3,2),(2,3),(4,3),(3,3)]:
 a=np_rng.normal(size=(msize,nsize))
 for scale in [1e-120,1e-20,1.,1e20,1e120]:
  aa=a*scale;arg=lit(aa);sv=np.linalg.svd(a,compute_uv=False);inv=np.linalg.pinv(a)
  for i,v in enumerate(sv):case(f'm.svd({arg}).values[{i}] / {lit(scale)}',v,1e-7)
  for i,j in np.ndindex(inv.shape):case(f'm.pseudoinverse({arg})[{i}][{j}] * {lit(scale)}',inv[i,j],1e-7)
  if msize==nsize:
   b=aa.T@aa if scale==1 else a.T@a
   # Separate normalized SPD eigenproblems for tiny and huge scales.
   b=(a.T@a)*scale;argb=lit(b);ev=np.linalg.eigvalsh(a.T@a)
   for i,v in enumerate(ev):case(f'm.eigenSymmetric({argb}).values[{i}] / {lit(scale)}',v)
for scale in [1e-20,1.,1e20]:
 a=np.array([[1,2],[2,4],[3,6.]])*scale;inv=np.linalg.pinv(a/scale)
 for i,j in np.ndindex(inv.shape):case(f'm.pseudoinverse({lit(a)})[{i}][{j}] * {lit(scale)}',inv[i,j],1e-7)
case('m.rank([[1e-100,0.0],[0.0,2e-100]])',2,0,0)
for _ in range(4):
 a=np_rng.normal(size=(3,3));a=a.T@a+np.eye(3);b=np_rng.normal(size=3);al=lit(a);bl=lit(b)
 for i,v in enumerate(np.linalg.solve(a,b)):case(f'm.solveLinear({al},{bl})[{i}]',v)
 for name,ref in [('inverse',np.linalg.inv),('matrixExp',__import__('scipy').linalg.expm),('matrixSqrt',__import__('scipy').linalg.sqrtm),('matrixLog',__import__('scipy').linalg.logm)]:
  expected=ref(a)
  for i,j in np.ndindex(a.shape):case(f'm.{name}({al})[{i}][{j}]',expected[i,j],1e-7)
 for i,v in enumerate(np.linalg.solve(a,b)):
  for name in ['gmres','bicgstab','conjugateGradient']:case(f'm.{name}({al},{bl})[{i}]',v,1e-6)
for scale in [1e-120,1e120]:
 case(f'm.matrixSqrt([[{lit(scale)}]])[0][0] / {lit(math.sqrt(scale))}',1.)
 case(f'm.matrixLog([[{lit(scale)}]])[0][0]',math.log(scale))
# SVD and QR reconstruction and orthogonality, including a singular SVD.
for a in [np.zeros((3,2)),np.array([[1.,2],[2,4],[3,6]]),np.array([[1,2],[3,4],[5,7.]])]:
 arg=lit(a);m0,n0=a.shape
 for i,j in np.ndindex((n0,n0)):
  case(f'm.matmul(m.transpose(m.svd({arg}).u),m.svd({arg}).u)[{i}][{j}]',float(i==j),1e-7)
for a in [np.array([[1,2],[3,4],[5,7.]])*scale for scale in [1e-120,1.,1e120]]:
 arg=lit(a)
 for i,j in np.ndindex(a.shape):case(f'm.matmul(m.qr({arg}).q,m.qr({arg}).r)[{i}][{j}] / {lit(float(np.max(np.abs(a))))}',a[i,j]/np.max(np.abs(a)))
# FFT, any-length FFT, transforms and polynomial/interpolation identities.
for n in [1,2,3,4,7,8,11]:
 a=np_rng.normal(size=n);arg=lit(a);z='['+','.join(f'm.Complex(real:{lit(x)},imag:0.0)' for x in a)+']'
 ref=np.fft.fft(a)
 for i,v in enumerate(ref):
  name='fft' if n&(n-1)==0 else 'fftAny'
  case(f'm.{name}({z})[{i}].real',v.real);case(f'm.{name}({z})[{i}].imag',v.imag)
  case(f'm.ifftAny(m.fftAny({z}))[{i}].real',a[i])
 for i,v in enumerate(a):case(f'm.idct(m.dct({arg}))[{i}]',v)
 if n&(n-1)==0:
  for i,v in enumerate(a):case(f'm.inverseHaar(m.haar({arg}))[{i}]',v)
for p in [2,3,4,5,6,7,8]:add('gaussLegendre',['(double x)=>x*x*x*x',-1.,1.,p],.4 if p>=3 else 2/9)
case('m.bisect((double x)=>1e-300*(x-0.25),0.0,1.0,60)',.25)
# Distribution parameter grids / endpoints / stable central CDFs.
for n,p in [(1000,.99),(2000,.5),(10000,.1)]:
 for k in [int(n*p),int(n*p-2*math.sqrt(n*p*(1-p)))]:add('binomialCdf',[k,n,p],st.binom.cdf(k,n,p))
for x in [1e-12,1e-6,1.,20.]:
 add('exponentialCdf',[x,2.],st.expon.cdf(x,scale=.5),1e-10,1e-20)
 add('weibullCdf',[x,.5,2.],st.weibull_min.cdf(x,.5,scale=2),1e-10,1e-20)
# Deterministic distribution checks use eight standard errors, not an assertion
# about one random draw. The seed and sample count are part of the fixture.
for expr,mean,var in [
 ('m.exponentialSample(r,2.0)',.5,.25),('m.weibullSample(r,2.0,3.0)',3*sp.gamma(1.5),9*(sp.gamma(2)-sp.gamma(1.5)**2)),
 ('m.geometricSample(r,0.3).toDouble()',.7/.3,.7/.09),('m.studentSample(r,5.0)',0.,5/3),
 ('m.lognormalSample(r,0.2,0.7)',math.exp(.2+.49/2),(math.exp(.49)-1)*math.exp(.4+.49)),
 ('m.poissonSample(r,1000.0).toDouble()',1000.,1000.),('m.gammaSample(r,0.2,2.0)',.4,.8),
 ('m.betaSample(r,2.0,5.0)',2/7,10/(49*8)),('m.binomialSample(r,100,0.3).toDouble()',30.,21.)]:
 case(f'sampleMean((math.Random r)=>{expr},20000,17)',mean,0,8*math.sqrt(var/20000))
case('sampleMedian((math.Random r)=>m.cauchySample(r,0.2,0.7),20000,19)',.2,0,.08)
# Loss-of-significance and endpoint regressions at representable tiny scales.
for name,ref in [('sinh',math.sinh),('tanh',math.tanh),('atanh',math.atanh),('log1p',math.log1p),('expm1',math.expm1)]:
 for x in [-1e-200,-1e-20,1e-20,1e-200]:add(name,[x],ref(x),1e-12,0.)
for name,ref in [('sinh',math.sinh),('cosh',math.cosh)]:add(name,[710.],ref(710.),1e-12,0.)
add('log1p',[1e308],math.log1p(1e308),1e-12)
add('wrapRadians',[1e20],math.remainder(1e20,2*math.pi),1e-12)
case('m.lerp(-1e308,1e308,0.5)',0.,0.,0.)
case('m.inverseLerp(-1e308,1e308,0.0)',.5)
case('(m.fraction(4611686018427387904,3)*m.fraction(3,2305843009213693952)).numerator',2,0,0)
case('(m.fraction(1,4611686018427387904)+m.fraction(1,4611686018427387904)).denominator',2305843009213693952,0,0)
case('m.fraction((-9223372036854775807-1),(-9223372036854775807-1)).numerator',1,0,0)
# Non-symmetric eigenproblems, optimization, physical and ODE identities.
from scipy import optimize as opt
for _ in range(8):
 a=np_rng.normal(size=(3,3));arg=lit(a);roots=sorted(np.linalg.eigvals(a),key=lambda z:(z.real,z.imag))
 for i,z in enumerate(roots):
  case(f'm.eigenvalues({arg})[{i}].real',z.real,1e-6)
  case(f'm.eigenvalues({arg})[{i}].imag',z.imag,1e-6)
for _ in range(5):
 costs=np_rng.uniform(.1,3,size=3);a=np_rng.uniform(.1,3,size=(5,3));b=np_rng.uniform(1,5,size=5)
 answer=opt.linprog(-costs,A_ub=a,b_ub=b,bounds=(0,None),method='highs')
 case(f'm.linearProgram({lit(costs)},{lit(a)},{lit(b)}).value',-answer.fun)
case('m.linearProgram([10.0,-57.0,-9.0,-24.0],[[0.5,-5.5,-2.5,9.0],[0.5,-1.5,-0.5,1.0],[1.0,0.0,0.0,0.0]],[0.0,0.0,1.0]).value',1.)
for factor in [1e-50,1.,1e50]:
 for name in ['conjugateGradient','bicgstab','gmres']:
  case(f'm.{name}([[4.0,1.0],[1.0,3.0]],[{lit(factor)},{lit(2*factor)}])[0] / {lit(factor)}',1/11,1e-6)
for points in [4,8,16]:
 h=1/points
 case(f'm.implicitEuler((double x,List<double> y)=>[-50*y[0]],0.0,[1.0],1.0,{points})[0]',(1+50*h)**(-points),1e-6)
 # BDF2 with a manufactured linear solution has no truncation error.
 case(f'm.bdf2((double x,List<double> y)=>[2.0],0.0,[1.0],1.0,{points})[0]',3.,1e-8)
case('m.firstEvent((double x,List<double> y)=>[1.0],(double x,List<double> y)=>1e-300*(y[0]-0.25),0.0,[0.0],1.0).at',.25)
# Class methods (all numerical value-class methods get exercised).
import cmath
z=complex(.7,-.3)
for method,ref in [('abs',abs),('argument',cmath.phase),('exponential',cmath.exp),('logarithm',cmath.log),('squareRoot',cmath.sqrt),('sine',cmath.sin),('cosine',cmath.cos)]:
 actual=f'm.Complex(real:0.7,imag:-0.3).{method}()';value=ref(z)
 if isinstance(value,complex):case(actual+'.real',value.real);case(actual+'.imag',value.imag)
 else:case(actual,value)
for expr,value in {
 'm.Complex.polar(2.0,0.0).real':2.,'m.Complex(real:1.0,imag:2.0).scale(3.0).imag':6.,
 'm.Complex(real:1.0,imag:2.0).conjugate().imag':-2.,'m.Vec2(x:3.0,y:4.0).normalized().length()':1.,
 'm.Vec2(x:1.0,y:2.0).dot(m.Vec2(x:3.0,y:4.0))':11.,'m.Vec2(x:1.0,y:2.0).cross(m.Vec2(x:3.0,y:4.0))':-2.,
 'm.Vec2(x:1.0,y:2.0).distance(m.Vec2(x:4.0,y:6.0))':5.,'m.Vec2(x:1.0,y:2.0).lerpTo(m.Vec2(x:3.0,y:4.0),0.25).x':1.5,
 'm.Vec3(x:1.0,y:2.0,z:2.0).normalized().length()':1.,'m.Vec3(x:1.0,y:2.0,z:2.0).scale(3.0).z':6.,
 'm.Vec3(x:1.0,y:2.0,z:2.0).dot(m.Vec3(x:3.0,y:4.0,z:5.0))':21.,
 'm.Vec3(x:1.0,y:0.0,z:0.0).cross(m.Vec3(x:0.0,y:1.0,z:0.0)).z':1.,
 'm.Vec3(x:1.0,y:2.0,z:2.0).distance(m.Vec3(x:1.0,y:2.0,z:5.0))':3.,
 'm.Interval(low:1.0,high:3.0).width()':2.,'m.Interval(low:1.0,high:3.0).limit(5.0)':3.,
 '(m.Interval(low:1.0,high:3.0).contains(2.0)?1:0)':1.,'(m.Interval(low:1.0,high:3.0).valid()?1:0)':1.,
 '(m.Interval(low:1.0,high:3.0).overlaps(m.Interval(low:2.0,high:4.0))?1:0)':1.,
 'm.summarize([1.0,2.0,3.0]).stddev()':1.,
}.items():case(expr,value)
# Independent high precision anchors where ordinary libm / SciPy can underflow.
import mpmath as mp
with mp.workdps(80):
 for x in [-171.5,-170.5]:add('gamma',[x],float(mp.gamma(x)),1e-9,0.)
 add('logGamma',[1e-320],float(mp.loggamma(mp.mpf(1e-320))),1e-12,0.)
 add('lambertW',[1e308],float(mp.lambertw(mp.mpf(1e308))),1e-12,0.)
 x=-1/math.e+1e-12
 add('lambertW',[x],float(mp.lambertw(mp.mpf(x)).real),1e-9,0.)
for x in [-12.,-8.,-5.]:add('normalCdf',[x,0.,1.],st.norm.cdf(x),1e-7,0.)
for x in [1e-100,1e-20]:add('chiSquareCdf',[x,5.],st.chi2.cdf(x,5),1e-7,0.)
add('binomialPmf',[100,1000,.001],st.binom.pmf(100,1000,.001),1e-7,0.)
add('fisherCdf',[1e308,10.,5.],1.,1e-12,0.)
case('m.Vec2(x:1e-320,y:1e-320).normalized().length()',1.)
case('m.Vec3(x:1.5e308,y:1.5e308,z:1.5e308).normalized().length()',1.)
case('(m.Complex(real:1e308,imag:1e308)/m.Complex(real:1e-308,imag:1e-308)).imag',0.,0.,0.)
case('m.Complex(real:1.5e308,imag:1.5e308).logarithm().real',math.log(1.5e308)+math.log(math.sqrt(2)))
case('m.Complex(real:1.5e308,imag:1.5e308).squareRoot().real / 1e154',cmath.sqrt(complex(1.5,1.5)).real)
case('m.stddev([-1e308,1e308]) / 1e308',math.sqrt(2))
case('m.correlation([-1e154,1e154],[-1e154,1e154])',1.)
vals=[(i+.5)/100 for i in range(100)];lam=(math.sqrt(100)+.12+.11/math.sqrt(100))*.005
case('m.kolmogorovSmirnov('+lit(vals)+',(double x)=>x).probability',st.kstwobign.sf(lam))
case('m.mannWhitney([1.0,1.0,1.0,2.0],[1.0,2.0,2.0,3.0]).probability',st.mannwhitneyu([1,1,1,2],[1,2,2,3],method='asymptotic',use_continuity=False).pvalue)
for expr,expected in {
 'm.Reals(180.0).toRadians()':math.pi,'m.Reals(math.pi).toDegrees()':180.,'m.Reals(-1.25).fractionalPart()':.75,
 '(m.Reals(1.0).about(1.0)?1:0)':1.,'m.Factors(5).factorial()':120.,'(m.Factors(7).prime()?1:0)':1.,
 'm.Samples([1.0,2.0,3.0]).sumOf()':6.,'m.Samples([1.0,2.0,3.0]).mean()':2.,
 'm.Samples([1.0,2.0,3.0]).median()':2.,'m.Samples([1.0,2.0,3.0]).stddev()':1.,
 'm.Samples([1.0,2.0,3.0]).minimum()':1.,'m.Samples([1.0,2.0,3.0]).maximum()':3.,
}.items():case(expr,expected)
case('m.kendall([1e-200,2e-200,3e-200],[3e-200,2e-200,1e-200])',-1.,0.,0.)
case('m.kendallB([1e-200,2e-200,3e-200],[3e-200,2e-200,1e-200])',-1.,1e-12,0.)
case('m.sparseConjugateGradient([0,1,0,1],[0,1,1,0],[4.0,3.0,1.0,1.0],[1e-50,2e-50],2)[0] / 1e-50',1/11,1e-6)
case('(m.hypot(0.0,double.nan).isNaN?1:0)',1,0,0)
case('m.adaptiveIntegral((double x)=>x*x*x*x,0.0,1.0,1e-10).value',.2,1e-10,1e-12)
case('m.adaptiveIntegral((double x)=>x*x*x*x,0.0,1.0,1e-10).error',0.,0.,1e-10)
for n in [0,1,5,10]:
 for x in [20.,50.]:add('besselK',[n,x],sp.kv(n,x),2e-6,0.)
add('besselJ',[10,.1],sp.jv(10,.1),1e-9,0.)
for x in [8.,10.,12.]:add('airyAi',[x],sp.airy(x)[0],1e-7,0.)
for x in [5.,10.,20.]:add('erfc',[x],sp.erfc(x),1e-10,0.)
for _ in range(50):
 a=rng.randrange(-2**63+1,2**63);b=rng.randrange(-2**63+1,2**63)
 call=f'm.extendedGcd({a},{b})'
 case(f'(BigInt.from({a})*BigInt.from({call}.x)+BigInt.from({b})*BigInt.from({call}.y)==BigInt.from({call}.divisor)?1:0)',1,0,0)
case('rejects(()=>m.extendedGcd((-9223372036854775807-1),0))',1,0,0)
case('rejects(()=>m.kendallB([1.0,1.0],[2.0,3.0]))',1,0,0)
case('rejects(()=>m.kendall([1.0,1.0],[2.0,2.0]))',1,0,0)
case('m.oneWayAnova([[1.0,1.0],[2.0,2.0]]).statistic',math.inf)
for a,b in [([1.,2.,3.,4.],[2.,4.,5.,6.]),([1.,1.,2.,4.],[0.,3.,3.,5.])]:
 case(f'm.oneSampleT({lit(a)},0.0).statistic',st.ttest_1samp(a,0).statistic)
 case(f'm.oneSampleT({lit(a)},0.0).probability',st.ttest_1samp(a,0).pvalue)
 case(f'm.twoSampleT({lit(a)},{lit(b)}).probability',st.ttest_ind(a,b,equal_var=True).pvalue)
 case(f'm.spearman({lit(a)},{lit(b)})',st.spearmanr(a,b).statistic)
 case(f'm.kendallB({lit(a)},{lit(b)})',st.kendalltau(a,b).statistic)
add('normalPdf',[0.,0.,1e308],1/math.sqrt(2*math.pi)/1e308,1e-10,0.)
add('normalCdf',[1e308,-1e308,1e308],st.norm.cdf(2),1e-10,0.)
add('cauchyPdf',[0.,0.,1e308],1/math.pi/1e308,1e-10,0.)
add('lognormalPdf',[1e308,math.log(1e308),1.],1/math.sqrt(2*math.pi)/1e308,1e-10,0.)
case('rejects(()=>m.implicitEuler((double x,List<double> y)=>[math.exp(y[0])],0.0,[10.0],1.0,1))',1,0,0)

add('fisherCdf',[1e-308,.1,100.],st.f.cdf(1e-308,.1,100.),1e-7,0.)
# Cases persisted separately so the same references can be embedded in a fixture.

header='''import 'dart:math' as math;\nimport 'dart:convert';\nimport 'dart:io';\nimport 'quds_math.dart' as m;\nint total=0, failures=0;\nvoid check(String expr,num Function() f,num expected,double relative,double absolute){\n total++; try { final actual=f(); if(actual==expected)return; if(actual.isFinite && expected.isFinite && (actual-expected).abs() <= absolute+relative*expected.abs())return; failures++; print(jsonEncode({'expr':expr,'actual':'$actual','expected':'$expected'})); } catch(e){failures++;print(jsonEncode({'expr':expr,'error':'$e'}));}\n}\ndouble sampleMean(double Function(math.Random) f,int n,int seed){final r=math.Random(seed);var sum=0.0;for(var i=0;i<n;i++){sum+=f(r);}return sum/n;}\ndouble sampleMedian(double Function(math.Random) f,int n,int seed){final r=math.Random(seed);final values=List.generate(n,(_)=>f(r))..sort();return (values[n~/2-1]+values[n~/2])/2;}\nnum rejects(Function f){try {f();return 0;}catch(_){return 1;}}\nvoid main(){\n'''
body=''.join('check('+json.dumps(e)+', () => '+e+', '+lit(v)+', '+lit(r)+', '+lit(a)+');\n' for e,v,r,a in cases)
Path('test/fixtures/math_reference.dart.txt').write_text(header+body+"print('TOTAL=$total FAILURES=$failures');exitCode=failures==0?0:1;\n}\n")
print(len(cases))

# The primary numerical reference suite is Quds source. Only structured add()
# cases are rendered here; Dart-only raw expressions remain supplemental tests.
# Both fixtures consume the same independently computed values and tolerances.
quds_header='''# Generated by tool/generate_math_reference.py from independent references.
# Run: quds test test/math_reference.quds
use quds:math as m
use dart:core show double

class _ReferenceCount:
  var value: int = 0

_reference(counter: _ReferenceCount, description: String, actual: double, expected: double, relative: double, absolute: double):
  counter.value += 1
  if actual == expected: return
  expect(actual.isFinite and expected.isFinite, true, reason: description)
  var gap = actual - expected
  if gap < 0.0: gap = 0.0 - gap
  var magnitude = expected
  if magnitude < 0.0: magnitude = 0.0 - magnitude
  expect(gap <= absolute + relative * magnitude, true, reason: description)

test "independent numerical references in Quds":
  counter = _ReferenceCount()
'''
quds_body=''.join(
 f'  _reference(counter, "reference {i}: {e.split("(")[0]}", {e}, {lit(v)}, {lit(r)}, {lit(a)})\n'
 for i,(e,v,r,a) in enumerate(quds_cases,1))
Path('test/math_reference.quds').write_text(quds_header+quds_body+
 f'  expect(counter.value, {len(quds_cases)})\n'
 f'  print "QUDS NUMERIC CHECKS={len(quds_cases)} FAILURES=0"\n')
print(f'Quds numeric references: {len(quds_cases)}')

# Traceability, not a proof of all branches or numerical input domains.
import re
public = sorted(set(n for n in re.findall(
    r'^([A-Za-z_]\w*)\(', Path('lib/sdk/math.quds').read_text(), re.M)
    if not n.startswith('_')))
quds_tests = ''.join(Path(p).read_text() for p in (
    'test/math.quds', 'test/math_accuracy.quds', 'test/math_graph.quds',
    'test/math_reference.quds', 'test/math_api.quds',
    'test/math_graph_reference.quds', 'test/math_operators.quds',
    'test/math_weighted_graph.quds', 'test/math_exact.quds',
    'test/math_exact_reference.quds', 'test/math_autodiff.quds',
    'test/math_autodiff_reference.quds', 'test/math_autodiff_imports.quds',
    'test/math_autodiff_alias.quds', 'test/math_geometry.quds',
    'test/math_geometry_reference.quds', 'test/math_flow.quds',
    'test/math_plan.quds', 'test/math_symbolic.quds',
    'test/math_symbolic_imports.quds', 'test/math_symbolic_reference.quds',
    'test/math_interval.quds',
    'test/math_interval_reference.quds', 'test/math_interval_imports.quds'))
lines = ['# Math API check inventory', '',
    'Generated by `python tool/generate_math_reference.py`.', '',
    f'{len(public)} public top-level functions; {len(quds_cases)} primary Quds numerical checks; {len(cases)} supplemental frozen Dart checks.', '',
    'This table counts direct call sites in the Quds suites and reference expressions. '
    'It is a traceability inventory, not branch coverage or proof of correctness over '
    'all inputs. Classes and the three extensions have additional member checks. '
    'Graph functions additionally run against independent Quds oracles in '
    '`test/math_graph_reference.quds` and supplemental platform oracles in '
    '`test/math_graph_test.dart`; these are not counted as frozen numerical references.', '',
    '| Function | Quds call sites | Reference/identity call sites |',
    '| --- | ---: | ---: |']
for name in public:
    q = len(re.findall(r'\b' + re.escape(name) + r'\(', quds_tests))
    r = sum(len(re.findall(r'\bm\.' + re.escape(name) + r'\(', expr)) for expr, *_ in cases)
    assert q, f'No Quds call check for {name}'
    lines.append(f'| `{name}` | {q} | {r} |')
Path('docs/MATH_COVERAGE.md').write_text('\n'.join(lines) + '\n')
