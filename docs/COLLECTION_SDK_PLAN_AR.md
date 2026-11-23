# مخطط حزمة المجموعات وتراكيب البيانات — quds:collection

**التاريخ:** 2026-11-23. **أساس البدء:** `4197acf`.
**الحالة:** منفّذ بالكامل (الدفعات 0 إلى 5) في `lib/sdk/collection.quds` مع التضمين في `lib/src/sdk.dart`، والمرجع الإنجليزي في `docs/COLLECTION_REFERENCE.md`.

هذه الحزمة تغطي خوارزميات المجموعات وتراكيب البيانات العامة في أي برنامج Quds،
لتغطية النواقص اليومية المعروفة في مكتبة Dart القياسية (`dart:core` و`dart:collection`)
بدون `dynamic` وبتطابق كامل بين Dart VM وJavaScript/Web.

## قرارات المالك المنفّذة

1. **تسمية الحزمة:** `quds:collection` في ملف SDK واحد منظّم بـ12 قسمًا: `lib/sdk/collection.quds`.
2. **ترحيل `quds:ext`:** نُقلت امتدادات المجموعات الثلاثة (`extend List<T> Lists`،
   `extend Map<K, V> Maps`، `extend Set<T> Sets`) بعقودها الأصلية من `lib/sdk/ext.quds`
   إلى `quds:collection::extensions` وحُذفت من `lib/sdk/ext.quds` بالكامل دون إعادة
   تصدير أو alias أو طبقة توافق (بقيت `Ints` و`Doubles` في `quds:ext`).
3. **الحفاظ على `quds:core`:** بقي `lib/sdk/core.quds` كما هو (`Array`، `Dict`،
   `HashSet`، `Stack`، `Queue`، `Bag`، `:: typed`) دون حذف أو كسر، ووسّعت
   `quds:collection` التراكيب بتراكيب عالية الكفاءة (`Deque`، `RingBuffer`،
   `PriorityQueue`، `Multiset`، `LruCache`، `MultiMap`، `BiMap`، `BitSet`،
   `DisjointSet`، `Trie`).

## هيكل الأقسام المنفّذة (12 قسمًا)

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
└── :: extensions   امتدادات Lists/Maps/Sets المنقولة + امتدادات اختيارية إضافية
```

## حالة الدفعات

| الدفعة | الأقسام والمحتوى | الحالة والمرجع |
| --- | --- | --- |
| **0–1 — الأساس واليوميات** | `types`، `query`، `transform`، `maps`، `sets` + اختبارات الاستيراد وVM/JS | **مكتمل** (`66fdadc`) — `test/collection_core.quds`، `test/collection_imports.quds` |
| **2 — الترتيب والمساواة والفروق** | `sort`، `equality`، `diff` | **مكتمل** (`823ba76`) — `test/collection_sort_equality_diff.quds` |
| **3 — الطوابير والتراكيب الترابطية** | `queue` (`Deque`، `RingBuffer`، `PriorityQueue`)، `assoc` (`LruCache`، `MultiMap`، `BiMap`) | **مكتمل** (`ee8b432`) — `test/collection_structures.quds` |
| **4 — التراكيب المتخصصة** | `specialized` (`BitSet`، `DisjointSet`، `Trie`) | **مكتمل** (`7bfd419`) — `test/collection_specialized.quds` |
| **5 — الامتدادات والترحيل والتوثيق** | `extensions`، حذف `Lists`/`Maps`/`Sets` من `quds:ext`، الذهبي، LSP، `docs/COLLECTION_REFERENCE.md` | **مكتمل** — `test/collection_extensions.quds`، `test/collection_reject_ext_collections.quds`، `test/goldens/collection_slice.dart.txt` |

## إصلاحات المترجم المكشوفة أثناء التنفيذ (`lib/src/semantics.dart`)

- تحليل مهيّئات حقول الباني المولّد تلقائيًا (`constructor == null`) ضمن النطاق الجيني والمكتبي للكلاس المعلِن قبل `applyArguments`، وتجنّب استيراد المكتبة لنفسها عند `home == _activeLibrary`.
- مسح `_expected` الخارجي عند تحليل طرفي عمليات المقارنة والمساواة والعضوية (`==`، `!=`، `<`، `<=`، `>`، `>=`، `in`، `not in`) حتى لا يُفسد استنتاج النوع العام.
- اعتبار `Iterable<T>` متغايرًا (covariant) في `compatible()` لقبول `List<List<int>>` كـ`Iterable<Iterable<int>>`.
- دعم خاصية `Object.hashCode` العامة على أي نوع غير `void` بما في ذلك معاملات النوع غير المقيّدة `T`.
- منع الاستبدال المزدوج لمعاملات النوع في `callApplied` عند تطابق اسم معامل النوع بين المستدعي والمستدعى.
