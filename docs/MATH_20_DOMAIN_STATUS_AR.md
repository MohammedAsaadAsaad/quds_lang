# مراجعة المجالات الرياضية العشرين

هذه خريطة للمصدر والاختبارات، وليست شهادة باكتمال فروع الرياضيات.
الجدول يفرّق بين تنفيذ عقد محدود واكتمال المجال. جميع المجالات تبقى جزئية.
البنود 3–15 في MATH_PLAN ليست هي المجالات العشرين في خارطة التوسعة.

| # | المجال | المنفذ الذي له اختبارات قدس | ما لم يُغلق بعد |
| --- | --- | --- | --- |
| 1 | الأساسيات الحقيقية | scalar، استقرار ودوال زائدية، nextUp/nextDown ومراجع الدقة | توثيق/تغطية كل تراكيب NaN وInfinity و±0 وكل منطقة تقارب |
| 2 | الحساب الدقيق والموثوق | BigFraction وBigInt، Decimal بتقريب مسمّى، RealInterval | دقة عشرية متسامية عامة؛ برهان كل عملية interval وكل منصة |
| 3 | نظرية الأعداد | أولية وتحليل عوامل وCRT وحقول أولية محدودة | حقول امتداد، خوارزميات عوامل كبيرة وضمانات تشفيرية |
| 4 | التوافقيات | factorial/combinations ومتتاليات BigInt دقيقة ومولدات `nextPermutation`/`combinationsOf`/`permutationsOf` | واجهات دوال مولّدة عامة وتعدادات مقيدة أوسع |
| 5 | الرسوم | مسافات ومكونات وMST وتدفق ومطابقة و`graphBridges`/`articulationPoints`/`biconnectedComponents` مع أوراكل مستقل | الرسوم الهندسية ومطابقة الأوزان العامة |
| 6 | الجبر وكثيرات الحدود | عمليات عددية، معاملات رمزية دقيقة، حقول أولية | تحليل عوامل عام ومتعدد المتغيرات وGröbner |
| 7 | الحساب الرمزي | شجرة مستقلة وتبسيط محافظ واشتقاق/تكامل متعددات حدود | محرك افتراضات وفروع وحلول رمزية عامة وتكامل متسامٍ |
| 8 | الجبر الخطي | dense/sparse وحلول وتحللات وبواقي | rank-revealing أقوى، conditioning أشمل، backends كبيرة |
| 9 | الموترات والتفاضل الآلي | tensor رتبة 1–4 وmatmul، Dual/HyperDual/reverse | broadcasting عام وعمليات tensor AD شاملة وGPU |
| 10 | التحليل والتفاضل والتكامل | جذور وتكامل واستيفاء وحسابات عددية | خوارزميات المجالات الصعبة مع تقدير خطأ أقوى |
| 11 | الدوال الخاصة والمركبة | عائلات عددية بحدود عمل وفشل موثقة | عائلات scaled/complex وفروع أوسع وتحسينات مقسمة بالمجال |
| 12 | الهندسة | Vec2/Vec3، اتجاه/تقاطع/مساحة وحافة محدبة و`triangulatePolygon` و`polygonCentroid` و`pointToSegmentDistance` | meshes واستعلامات مكانية ثلاثية الأبعاد وDelaunay/Voronoi |
| 13 | الاحتمالات | توزيعات وعينات وlog-probability محدودة | survival لكل العائلات ومتعدد المتغيرات وmixtures/copulas |
| 14 | الإحصاء والاستدلال | وصف وانحدار، weighted/streaming/bootstrap، `cohenD`، `ridgeRegression`، و`logisticRegression` (GLM ثنائي) | GLM غير ثنائي وBayesian/MCMC وقوة اختبارات أوسع |
| 15 | التحسين وبحوث العمليات | scalar/multivariate، LP وphase-I | QP وقيود عامة وinteger/global optimization بضمانات |
| 16 | التحويلات والإشارات | FFT/DCT/Haar وSTFT وFIR بعقود normalization | مرشحات/resampling/wavelets وLaplace/Z أوسع |
| 17 | المعادلات والأنظمة الديناميكية | ODE وstiff step مع رفض عدم التقارب، بعض BVP/PDE | DAE وSDE وأنظمة stiff متناثرة أكبر وعقود أحداث أشمل |
| 18 | السلاسل الزمنية والعمليات العشوائية | covariance/ACF/PACF/difference، `arFit` (Yule-Walker) و`arForecast`، `exponentialSmoothing` و`holtForecast`، Markov وKalman | MA/ARIMA/SARIMA وstate-space متعدد الأبعاد وMCMC |
| 19 | المنطق والرياضيات المتقطعة | حزمة الأساس: CNF SAT محدود وفحص ترتيب جزئي | SAT صناعي وSMT وشبكات عامة ومحرك إثبات |
| 20 | الطوبولوجيا والهندسة التفاضلية | Euler للمثلثات؛ حزمة الأساس: Betti فوق F2 حتى البعد 2 | homology أعلى/بمعاملات عامة، persistence، manifolds/geodesics |

## الأدلة وإغلاق حزمة الأساس

الأساس الموجود موثّق في MATH_CONTRACTS وMATH_ACCURACY وMATH_COVERAGE،
وبعقود MATH_GRAPH/WEIGHTED_GRAPH/FLOW/EXACT/AUTODIFF/GEOMETRY/INTERVAL/SYMBOLIC
وMATH_PLAN. لا تُحسب حالة اختبار runner Dart كدليل مستقل إضافي عن assertions
قدس التي يشغّلها، ولا يُستنتج دعم كل الفروع من وجود call site.

حزمة الأساس محددة في EXECUTION_NEXT_STEPS_AR، وتضيف 9 دوال عامة و3 أنواع
نتائج، دون تغيير صياغة اللغة أو جعل Flutter اعتمادًا للرياضيات. عقودها في MATH_FOUNDATIONS، والمصدر والنسخة المضمنة متزامنان.
اختبارات قدس والمراجع الدقيقة والرفض وVM/JS موثّقة في VALIDATION مع نتيجة
الفحص الكامل. لا يعني إغلاق هذه العقود اكتمال الفروع المذكورة في عمود الناقص.
