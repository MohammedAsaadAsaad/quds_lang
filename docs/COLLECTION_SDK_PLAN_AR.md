# مخطط حزمة المجموعات وتراكيب البيانات — quds:collection

**التاريخ:** 2026-11-23. **أساس البدء:** `4197acf`.
**الحالة:** قيد التنفيذ التدريجي (الدفعة 0–1 قيد التسليم).

هذه الحزمة تغطي خوارزميات المجموعات وتراكيب البيانات العامة في أي برنامج Quds،
لتغطية النواقص اليومية المعروفة في مكتبة Dart القياسية (`dart:core` و`dart:collection`)
بدون `dynamic` وبتطابق كامل بين Dart VM وJavaScript/Web.

## قرارات المالك المعتمدة

1. **تسمية الحزمة:** `quds:collection` في ملف واحد منظّم بـ12 قسمًا: `lib/sdk/collection.quds`.
2. **ترحيل `quds:ext`:** تُنقل امتدادات المجموعات الثلاثة من `lib/sdk/ext.quds`
   (`extend List<T> Lists`، `extend Map<K, V> Maps`، `extend Set<T> Sets`) إلى
   `quds:collection::extensions` وتُحذف من `lib/sdk/ext.quds` بالكامل في الدفعة 5
   دون إعادة تصدير أو alias أو طبقة توافق (تبقى `Ints` و`Doubles` في `quds:ext`).
3. **الحفاظ على `quds:core`:** يبقى `lib/sdk/core.quds` كما هو (`Array`، `Dict`،
   `HashSet`، `Stack`، `Queue`، `Bag`، `:: typed`) دون حذف أو كسر، وتوسّع
   `quds:collection` تراكيب البيانات بتراكيب عالية الكفاءة (`Deque`، `RingBuffer`،
   `PriorityQueue`، `Multiset`، `LruCache`، `MultiMap`، `BiMap`، `BitSet`،
   `DisjointSet`، `Trie`).

## هيكل الأقسام (12 قسمًا)

```text
lib/sdk/collection.quds
│
├── :: types        الأنواع المشتركة ونتائج العمليات والسياسات والأخطاء
├── :: query        الاستعلام الآمن والبحث والحدود الدنيا/العليا
├── :: transform    التقسيم والتجميع والدمج والتحويل الوظيفي
├── :: sort         الترتيب المستقر والبحث الثنائي والاختيار (topK/bottomK)
├── :: maps         عمليات الخرائط ودمجها وعكسها وتصفيتها
├── :: sets         عمليات المجموعات والتكرارات وMultiset
├── :: queue        Deque (O(1)) وRingBuffer وPriorityQueue (Binary Heap)
├── :: assoc        LruCache وMultiMap وBiMap
├── :: specialized  BitSet (Uint32List) وDisjointSet (Union-Find) وTrie
├── :: equality     المساواة والتجزئة الهيكلية الصريحة بدون dynamic
├── :: diff         مقارنة وفروق القوائم والمجموعات والخرائط
└── :: extensions   امتدادات اختيارية (Lists/Maps/Sets المنقولة + امتدادات إضافية)
```

## خطة الدفعات وبوابات القبول

| الدفعة | الأقسام والمحتوى | الحالة |
| --- | --- | --- |
| **0–1 — الأساس واليوميات** | `types`، `query`، `transform`، `maps`، `sets` + اختبارات الاستيراد وVM/JS | قيد التنفيذ |
| **2 — الترتيب والمساواة والفروق** | `sort`، `equality`، `diff` | مخطط |
| **3 — الطوابير والتراكيب الترابطية** | `queue` (`Deque`، `RingBuffer`، `PriorityQueue`)، `assoc` (`LruCache`، `MultiMap`، `BiMap`) | مخطط |
| **4 — التراكيب المتخصصة** | `specialized` (`BitSet`، `DisjointSet`، `Trie`) | مخطط |
| **5 — الامتدادات والترحيل والتوثيق** | `extensions`، حذف `Lists`/`Maps`/`Sets` من `quds:ext`، الذهبي، LSP، `docs/COLLECTION_REFERENCE.md` | مخطط |

## قواعد العقود والتنفيذ

- جميع الدوال والتراكيب محددة الأنواع (strongly typed)؛ لا استخدام لـ`dynamic`.
- العقود صريحة مع المدخلات الفارغة والحدود الخارجة عن النطاق والمفاتيح المفقودة
  (`null` للبحث الآمن، `CollectionError` / `ArgumentError` للمعاملات غير الصالحة).
- الاختبارات الأساسية تُكتب بـ`.quds` وتُشغّل عبر `quds test` مع `expect(...)`،
  ويُتحقق من تطابق Dart VM و`dart compile js` + `node` مع `dart analyze --fatal-infos`.
- أي خلل يكشفه تنفيذ الحزمة في المترجم يُصلح في الدفعة نفسها مع اختبار regression.
