/// Multi-folder, asset-enabled Quds project templates for Quds Studio's
/// Project Workspace Manager (`quds:assets` + `quds:viz` + nested `use` imports).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

class StudioProjectTemplate {
  const StudioProjectTemplate({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    required this.accentColor,
    required this.builder,
    this.usesBenchmarkPolicy = false,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final Color accentColor;
  final QudsWorkspace Function() builder;
  final bool usesBenchmarkPolicy;
}

Uint8List _buildShopBannerBmp() {
  const w = 36;
  const h = 14;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      final border = x == 0 || y == 0 || x == w - 1 || y == h - 1;
      if (border) return [245, 158, 11]; // gold frame
      // Stylized emerald/cyan gradient + geometric Quds arch motif
      final cx = (x - w / 2).abs();
      final cy = y - h * 0.72;
      final inArch = (cx * cx) / 72.0 + (cy * cy) / 48.0 < 1.0 && y > 3;
      if (inArch) {
        return [250, 204, 21]; // warm dome gold
      }
      final r = (14 + x * 1.4).round().clamp(0, 255);
      final g = (95 + (h - y) * 9).round().clamp(0, 255);
      final b = (145 + x * 2.6).round().clamp(0, 255);
      return [r, g, b];
    });
  });
  return encodeQudsBmp24(rows, scale: 6);
}

Uint8List _buildPixelLogoBmp() {
  const art = [
    '................',
    '....CCCCCCCC....',
    '..CCGGGGGGGGCC..',
    '..CG........GC..',
    '.CG..YYYYYY..GC.',
    '.CG..Y....Y..GC.',
    '.CG..Y.MM.Y..GC.',
    '.CG..Y.MM.Y..GC.',
    '.CG..Y....Y..GC.',
    '.CG..YYYYYY..GC.',
    '..CG......YYGC..',
    '..CCGGGGGGYYCC..',
    '....CCCCCCCCYY..',
    '.............Y..',
    '................',
    '................',
  ];
  final palette = <String, List<int>>{
    '.': [11, 17, 32],
    'C': [56, 189, 248],
    'G': [16, 185, 129],
    'Y': [245, 158, 11],
    'M': [236, 72, 153],
  };
  final rows = art
      .map((line) => line.split('').map((ch) => palette[ch]!).toList())
      .toList();
  return encodeQudsBmp24(rows, scale: 8);
}

/// 1. Enhanced Orbital Lab (default workspace — preserves core/math/physics + adds assets/planets.json)
QudsWorkspace buildOrbitalLabProject() {
  final base = QudsWorkspace.scientificProjectTemplate();
  base.writeFile(
    'assets/planets.json',
    '''{
  "planets": [
    {"name": "Earth", "ar": "الأرض", "g": 9.81},
    {"name": "Moon", "ar": "القمر", "g": 1.62},
    {"name": "Mars", "ar": "المريخ", "g": 3.72},
    {"name": "Jupiter", "ar": "المشتري", "g": 24.79}
  ]
}
''',
  );
  return base;
}

/// 2. Interactive POS / Shop App with JSON catalog, CSV coupons, BMP banner & receipt export
QudsWorkspace buildQudsShopPosProject() => QudsWorkspace(
      name: 'quds_shop_pos',
      packageName: 'quds_shop_pos',
      entryPoint: 'main.quds',
      binaryAssets: {
        'assets/banner.bmp': _buildShopBannerBmp(),
      },
      files: {
        'assets/catalog.json': '''{
  "storeName": "متجر قدس الذكي — Quds Market",
  "currency": "USD",
  "vatRate": 0.15,
  "items": [
    {"sku": "OLV-01", "name": "زيت زيتون بكر ممتاز", "price": 24.50},
    {"sku": "DAT-02", "name": "تمر مجهول فاخر (1 كغ)", "price": 18.00},
    {"sku": "COF-03", "name": "قهوة عربية بالهيل", "price": 12.75},
    {"sku": "ZAT-04", "name": "زعتر بلدي مع سمسم", "price": 7.50}
  ]
}
''',
        'assets/coupons.csv': '''code,percent,minSubtotal,note
NONE,0,0,بدون خصم
QUDS10,10,20,خصم ترحيبي 10%
VIP20,20,60,خصم كبار العملاء 20%
EID25,25,100,عرض الموسم 25%
''',
        'models/cart.quds': '''# نماذج سلة المشتريات (models/cart.quds)
class CartLine:
  sku: String
  title: String
  qty: int
  unitPrice: double

  init(this.sku, this.title, this.qty, this.unitPrice)

  lineTotal() -> double:
    return qty * unitPrice
''',
        'services/pricing.quds':
            '''# محرك التسعير والخصومات والضريبة (services/pricing.quds)
use ^.models.cart show CartLine

computeSubtotal(lines: List<CartLine>) -> double:
  var sum = 0.0
  for item in lines:
    sum = sum + item.lineTotal()
  return sum

findCouponDiscount(coupons: List<dynamic>, code: String, subtotal: double) -> double:
  for row in coupons:
    if row["code"] == code:
      minSub = (row["minSubtotal"] as num).toDouble()
      pct = (row["percent"] as num).toDouble()
      if subtotal >= minSub:
        return subtotal * (pct / 100.0)
  return 0.0
''',
        'main.quds':
            r'''# تطبيق نقطة بيع تفاعلي متعدد المجلدات مع أصول JSON + CSV + BMP
use quds:assets as assets
use quds:viz as viz
use models.cart show CartLine
use services.pricing show computeSubtotal, findCouponDiscount

catalog = assets.readJson("assets/catalog.json")
coupons = assets.readCsv("assets/coupons.csv")
items = catalog["items"] as List

# مدخلات تفاعلية من المستخدم
q0 = viz.slider("q0", min: 0.0, max: 6.0, value: 2.0, step: 1.0, label: "زيت زيتون (كمية)").toInt()
q1 = viz.slider("q1", min: 0.0, max: 6.0, value: 3.0, step: 1.0, label: "تمر مجهول (كمية)").toInt()
q2 = viz.slider("q2", min: 0.0, max: 6.0, value: 2.0, step: 1.0, label: "قهوة عربية (كمية)").toInt()
q3 = viz.slider("q3", min: 0.0, max: 6.0, value: 1.0, step: 1.0, label: "زعتر بلدي (كمية)").toInt()
coupon = viz.select("coupon", ["NONE", "QUDS10", "VIP20", "EID25"], value: "VIP20", label: "كوبون الخصم")
express = viz.toggle("express", value: true, label: "توصيل سريع (+5.00 USD)")

qtys = [q0, q1, q2, q3]
var cart: List<CartLine> = []
var rows: List<List<dynamic>> = []

for i in 0..(items.length - 1):
  qty = qtys[i]
  if qty > 0:
    it = items[i]
    price = (it["price"] as num).toDouble()
    line = CartLine(it["sku"].toString(), it["name"].toString(), qty, price)
    cart.add(line)
    rows.add([line.sku, line.title, qty, price.toStringAsFixed(2), line.lineTotal().toStringAsFixed(2)])

subtotal = computeSubtotal(cart)
discount = findCouponDiscount(coupons, coupon, subtotal)
vatRate = (catalog["vatRate"] as num).toDouble()
taxable = subtotal - discount
vat = taxable * vatRate
var shipping = 0.0
if express and subtotal > 0.0:
  shipping = 5.0
grandTotal = taxable + vat + shipping

# حفظ آخر فاتورة كأصل JSON حي داخل مساحة المشروع
receipt = map:
  "store": catalog["storeName"]
  "coupon": coupon
  "itemCount": cart.length
  "subtotal": subtotal
  "discount": discount
  "vat": vat
  "shipping": shipping
  "grandTotal": grandTotal
assets.writeJson("assets/last_receipt.json", receipt)

# عرض الشعار الثنائي من assets/banner.bmp + بطاقة الفاتورة + جدول الأصناف
assets.renderImage("assets/banner.bmp", title: catalog["storeName"].toString(), caption: "تم تحميل الكتالوج من assets/catalog.json والكوبونات من assets/coupons.csv وحفظ الفاتورة في assets/last_receipt.json")

summary = map:
  "المجموع الفرعي": subtotal.toStringAsFixed(2) + " USD"
  "الخصم (" + coupon + ")": "-" + discount.toStringAsFixed(2) + " USD"
  "الضريبة (15%)": vat.toStringAsFixed(2) + " USD"
  "التوصيل": shipping.toStringAsFixed(2) + " USD"
  "الإجمالي النهائي": grandTotal.toStringAsFixed(2) + " USD"

viz.form(summary, title: "🧾 فاتورة متجر قدس التفاعلية", summary: "غيّر الكميات أو اختر كوبوناً لتحديث الفاتورة وحفظ assets/last_receipt.json فوراً")
viz.table(["SKU", "المنتج", "الكمية", "السعر", "الإجمالي"], rows, title: "تفاصيل سلة المشتريات")
print "فاتورة " + catalog["storeName"].toString() + " | الإجمالي = " + grandTotal.toStringAsFixed(2) + " USD"
''',
      },
    );

/// 3. Multi-Folder Sales Analytics Hub reading CSV + JSON assets
QudsWorkspace buildSalesAnalyticsHubProject() => QudsWorkspace(
      name: 'sales_analytics_hub',
      packageName: 'sales_analytics_hub',
      entryPoint: 'main.quds',
      files: {
        'assets/sales_2026.csv': '''month,region,revenue,orders,cost
1,North,42000,310,26500
2,North,46500,340,28200
3,North,51800,382,30900
4,North,55400,405,32600
5,North,61200,445,35100
6,North,66800,490,37800
1,South,34000,260,22100
2,South,37800,285,23900
3,South,41500,312,25800
4,South,44900,336,27400
5,South,49200,368,29500
6,South,53600,402,31700
''',
        'assets/targets.json': '''{
  "company": "قدس للتحليلات التجارية",
  "monthlyTarget": 48000,
  "marginGoalPct": 38.0
}
''',
        'analytics/loader.quds':
            '''# وحدة تحميل وتصفية بيانات CSV (analytics/loader.quds)
use quds:assets as assets

loadRegionSales(region: String) -> List<dynamic>:
  allRows = assets.readCsv("assets/sales_2026.csv")
  if region == "ALL":
    return allRows
  var out: List<dynamic> = []
  for r in allRows:
    if r["region"] == region:
      out.add(r)
  return out
''',
        'analytics/kpis.quds':
            '''# حساب مؤشرات الأداء المالي (analytics/kpis.quds)
marginPercent(revenue: double, cost: double) -> double:
  if revenue <= 0.0:
    return 0.0
  return ((revenue - cost) / revenue) * 100.0
''',
        'main.quds':
            r'''# لوحة تحليلات الأعمال متعددة الملفات (CSV + JSON Assets)
use quds:assets as assets
use quds:viz as viz
use analytics.loader show loadRegionSales
use analytics.kpis show marginPercent

targets = assets.readJson("assets/targets.json")
region = viz.select("region", ["ALL", "North", "South"], value: "North", label: "المنطقة الجغرافية")
boost = viz.slider("boost", min: 0.8, max: 1.4, value: 1.0, step: 0.05, label: "معامل محاكاة النمو")

rows = loadRegionSales(region)
baseTarget = (targets["monthlyTarget"] as num).toDouble()

var months: List<double> = []
var revenues: List<double> = []
var profits: List<double> = []
var tableRows: List<List<dynamic>> = []
var totalRev = 0.0
var totalCost = 0.0
var totalOrders = 0

for mIdx in 1..6:
  var rev = 0.0
  var cost = 0.0
  var orders = 0
  for r in rows:
    if (r["month"] as num).toInt() == mIdx:
      rev = rev + (r["revenue"] as num).toDouble() * boost
      cost = cost + (r["cost"] as num).toDouble()
      orders = orders + (r["orders"] as num).toInt()
  profit = rev - cost
  margin = marginPercent(rev, cost)
  totalRev = totalRev + rev
  totalCost = totalCost + cost
  totalOrders = totalOrders + orders
  months.add(mIdx.toDouble())
  revenues.add(rev / 1000.0)
  profits.add(profit / 1000.0)
  tableRows.add(["شهر " + mIdx, orders, rev.toStringAsFixed(0), profit.toStringAsFixed(0), margin.toStringAsFixed(1) + "%"])

avgMargin = marginPercent(totalRev, totalCost)
var regionMult = 1.0
if region == "ALL":
  regionMult = 2.0
targetSum = baseTarget * 6.0 * regionMult
attainment = (totalRev / targetSum) * 100.0

viz.plot(
  months,
  revenues,
  title: "أداء المبيعات النصف سنوي (ألف $) — المنطقة: " + region,
  xLabel: "الشهر",
  yLabel: "الإيرادات (ألف دولار)",
  color: "#38BDF8",
)
viz.table(["الشهر", "الطلبات", "الإيراد ($)", "الربح ($)", "الهامش"], tableRows, title: "ملخص KPI | التحقق من الهدف: " + attainment.toStringAsFixed(1) + "% | متوسط الهامش: " + avgMargin.toStringAsFixed(1) + "%")
print "تم تحليل " + rows.length + " سجلات CSV | إجمالي الإيراد = " + totalRev.toStringAsFixed(0) + " | الهامش = " + avgMargin.toStringAsFixed(1) + "%"
''',
      },
    );

/// 4. Sandboxed Extensions / Plugins Host Architecture Demo
QudsWorkspace buildExtensionsHostProject() => QudsWorkspace(
      name: 'quds_extensions_host',
      packageName: 'quds_extensions_host',
      entryPoint: 'main.quds',
      files: {
        'assets/plugins.json': '''{
  "hostApp": "Quds Commerce & CRM Host v1.2",
  "sandboxPolicy": "strict-capabilities",
  "extensions": [
    {"id": "smart_discount", "name": "إضافة الخصم الذكي", "version": "1.0.0", "enabled": true},
    {"id": "health_score", "name": "إضافة تقييم صحة العميل", "version": "1.2.0", "enabled": true},
    {"id": "arabic_badge", "name": "إضافة شارة الولاء العربية", "version": "1.1.0", "enabled": true}
  ]
}
''',
        'core/plugin_api.quds':
            '''# عقد واجهة الإضافات (Extension Contract — core/plugin_api.quds)
class ExtensionOutput:
  pluginId: String
  title: String
  summary: String
  deltaScore: double

  init(this.pluginId, this.title, this.summary, this.deltaScore)
''',
        'extensions/smart_discount.quds':
            '''# إضافة خارجية 1: محرك خصومات ذكي قابل للتفعيل والتعطيل
use ^.core.plugin_api show ExtensionOutput

runDiscountExtension(orderAmount: double, visits: int) -> ExtensionOutput:
  var rate = 0.0
  if orderAmount >= 200.0:
    rate = 15.0
  else if orderAmount >= 100.0:
    rate = 10.0
  else if visits >= 5:
    rate = 7.5
  saved = orderAmount * (rate / 100.0)
  return ExtensionOutput(
    "smart_discount",
    "الخصم الذكي",
    "نسبة " + rate.toStringAsFixed(1) + "% (توفير " + saved.toStringAsFixed(2) + " USD)",
    rate,
  )
''',
        'extensions/health_score.quds':
            '''# إضافة خارجية 2: مؤشر تقييم ولاء ونشاط العميل
use ^.core.plugin_api show ExtensionOutput

runHealthExtension(orderAmount: double, visits: int, supportTickets: int) -> ExtensionOutput:
  raw = 50.0 + visits * 4.5 + (orderAmount / 25.0) - supportTickets * 8.0
  var score = raw
  if score > 100.0:
    score = 100.0
  if score < 0.0:
    score = 0.0
  var tier = "يحتاج متابعة"
  if score >= 80.0:
    tier = "ممتاز"
  else if score >= 60.0:
    tier = "جيد"
  return ExtensionOutput(
    "health_score",
    "مؤشر صحة العميل",
    score.toStringAsFixed(1) + "/100 (" + tier + ")",
    score,
  )
''',
        'extensions/arabic_badge.quds':
            '''# إضافة خارجية 3: توليد شارة ورسالة ترحيب مخصصة
use ^.core.plugin_api show ExtensionOutput

runBadgeExtension(customer: String, orderAmount: double, visits: int) -> ExtensionOutput:
  var badge = "🌿 عضو مرحّب به"
  if visits >= 10:
    badge = "👑 سفير قدس"
  else if orderAmount >= 150.0:
    badge = "⭐ عميل ذهبي"
  return ExtensionOutput(
    "arabic_badge",
    "شارة الولاء",
    badge + " — أهلاً بك يا " + customer,
    10.0,
  )
''',
        'main.quds':
            r'''# نموذج معماري حي لنظام الإضافات (Extensions Host) بلغة قدس!
use quds:assets as assets
use quds:viz as viz
use core.plugin_api show ExtensionOutput
use extensions.smart_discount show runDiscountExtension
use extensions.health_score show runHealthExtension
use extensions.arabic_badge show runBadgeExtension

manifest = assets.readJson("assets/plugins.json")

# مدخلات التطبيق المضيف + مفاتيح تفعيل/تعطيل كل إضافة لحظياً
customer = viz.input("customer", value: "أحمد", label: "اسم العميل")
orderAmount = viz.slider("orderAmount", min: 20.0, max: 400.0, value: 185.0, step: 5.0, label: "قيمة الطلب ($)")
visits = viz.slider("visits", min: 1.0, max: 20.0, value: 8.0, step: 1.0, label: "عدد الزيارات").toInt()
tickets = viz.slider("tickets", min: 0.0, max: 6.0, value: 1.0, step: 1.0, label: "تذاكر الدعم").toInt()

enDiscount = viz.toggle("enDiscount", value: true, label: "تفعيل إضافة الخصم الذكي")
enHealth = viz.toggle("enHealth", value: true, label: "تفعيل إضافة صحة العميل")
enBadge = viz.toggle("enBadge", value: true, label: "تفعيل إضافة شارة الولاء")

var executed: List<ExtensionOutput> = []
if enDiscount:
  executed.add(runDiscountExtension(orderAmount, visits))
if enHealth:
  executed.add(runHealthExtension(orderAmount, visits, tickets))
if enBadge:
  executed.add(runBadgeExtension(customer, orderAmount, visits))

var tableRows: List<List<dynamic>> = []
var totalImpact = 0.0
for out in executed:
  totalImpact = totalImpact + out.deltaScore
  tableRows.add([out.pluginId, out.title, out.summary, out.deltaScore.toStringAsFixed(1)])

# حفظ سجل تدقيق الإضافات داخل assets/audit.json
audit = map:
  "host": manifest["hostApp"]
  "customer": customer
  "activeExtensions": executed.length
  "totalImpact": totalImpact
assets.writeJson("assets/audit.json", audit)

summary = map:
  "التطبيق المضيف": manifest["hostApp"]
  "العميل": customer
  "الإضافات المفعّلة": "{executed.length} / 3"
  "سياسة الأمان": manifest["sandboxPolicy"]
  "سجل التدقيق": "assets/audit.json"

viz.form(summary, title: "🧩 مضيف إضافات قدس (Quds Extensions Host)", summary: "كل إضافة تعمل كملف .quds معزول داخل مجلد extensions/ وتقرأ إعداداتها من assets/plugins.json")
viz.table(["معرّف الإضافة", "الاسم", "مخرجات الإضافة", "الأثر"], tableRows, title: "مخرجات الإضافات المنفّذة داخل Sandbox")
print "تم تنفيذ {executed.length} إضافات بأمان | العميل: {customer}"
''',
      },
    );

/// 5. Binary Image & Pixel Asset Studio (BMP + Palettes JSON + Procedural Filters)
QudsWorkspace buildPixelAssetStudioProject() => QudsWorkspace(
      name: 'pixel_asset_studio',
      packageName: 'pixel_asset_studio',
      entryPoint: 'main.quds',
      binaryAssets: {
        'assets/logo.bmp': _buildPixelLogoBmp(),
      },
      files: {
        'assets/palettes.json': '''{
  "ocean": ["#0B1120", "#0284C7", "#38BDF8", "#10B981", "#F0FDF4"],
  "sunset": ["#1E1B4B", "#7C3AED", "#EC4899", "#F59E0B", "#FEF3C7"],
  "emerald": ["#064E3B", "#059669", "#10B981", "#34D399", "#ECFDF5"]
}
''',
        'filters/generator.quds':
            '''# مولّد أنماط بكسل هندسية من لوحات ألوان JSON (filters/generator.quds)
use dart:math as m

buildWavePattern(size: int, freq: double, palette: List<dynamic>) -> List<List<dynamic>>:
  var grid: List<List<dynamic>> = []
  nColors = palette.length
  for y in 0..(size - 1):
    var row: List<dynamic> = []
    for x in 0..(size - 1):
      dx = (x - size / 2.0) / (size / 2.0)
      dy = (y - size / 2.0) / (size / 2.0)
      dist = m.sqrt(dx * dx + dy * dy)
      wave = (m.sin(dist * freq * 3.14159) + 1.0) * 0.5
      var idx = (wave * (nColors - 1)).round()
      if idx < 0:
        idx = 0
      if idx >= nColors:
        idx = nColors - 1
      row.add(palette[idx])
    grid.add(row)
  return grid
''',
        'main.quds':
            r'''# استوديو الأصول الثنائية وتوليد الصور (assets/logo.bmp + assets/palettes.json)
use quds:assets as assets
use quds:viz as viz
use filters.generator show buildWavePattern

palettes = assets.readJson("assets/palettes.json")
logoInfo = assets.info("assets/logo.bmp")

themeName = viz.select("theme", ["ocean", "sunset", "emerald"], value: "ocean", label: "لوحة الألوان (JSON)")
freq = viz.slider("freq", min: 1.0, max: 6.0, value: 3.0, step: 0.5, label: "تردد الموجة البصرية")
resSize = viz.slider("resSize", min: 12.0, max: 32.0, value: 20.0, step: 4.0, label: "دقة الشبكة (بكسل)").toInt()

selectedPalette = palettes[themeName] as List
grid = buildWavePattern(resSize, freq, selectedPalette)

# 1. عرض الصورة الثنائية الأصلية المخزّنة داخل assets/logo.bmp
assets.renderImage("assets/logo.bmp", title: "🖼️ الأصل الثنائي: assets/logo.bmp", caption: "الحجم: {logoInfo['bytes']} بايت · النوع: {logoInfo['mimeType']}")

# 2. توليد ورسم صورة BMP جديدة ديناميكياً من شبكة البكسل
assets.renderPixelGrid(grid, title: "🎨 صورة مولّدة حياً بلوحة {themeName}", scale: 8, caption: "دقة {resSize}×{resSize} مولّدة عبر filters/generator.quds + assets/palettes.json")

infoCard = map:
  "الأصل الثنائي": logoInfo["path"]
  "حجم logo.bmp": "{logoInfo['bytes']} B"
  "لوحة الألوان": themeName
  "عدد ملفات assets/": assets.list("assets").length

viz.form(infoCard, title: "📦 بيانات أصول المشروع", summary: "يمكنك إضافة أو تعديل ملفات assets/ مباشرة من شجرة المشروع وإعادة التشغيل")
print "تم عرض assets/logo.bmp وتوليد شبكة {resSize}x{resSize} بلوحة {themeName}"
''',
      },
    );

/// 6. Heavy Multi-Folder Algorithm & Compiled Bytecode Lab
///
/// 5 nested folders (`core/config/`, `math/kernels/`, `math/`, `domain/report/`,
/// `assets/`) designed specifically to compare AST vs Cold Bytecode vs
/// Precompiled/Cached `.qbc` Artifacts and inspect compiled bytecode files live.
QudsWorkspace buildHeavyVmLabProject() => QudsWorkspace(
      name: 'quds_heavy_vm_lab',
      packageName: 'quds_heavy_vm_lab',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      files: {
        'assets/suite.json': '''{
  "suite": "Quds Heavy Multi-Folder VM Lab",
  "version": "1.0.0",
  "kernels": [
    "math/kernels/sieve.quds",
    "math/kernels/matmul.quds",
    "math/kernels/nbody.quds",
    "math/kernels/mandelbrot.quds"
  ],
  "modes": ["AST", "Cold Bytecode", "Precompiled Cached"]
}
''',
        'core/config/workload.quds':
            '''# Heavy benchmark parameters — edit any value and watch only this file recompile!
SUITE_LABEL = "Heavy 4-Kernel Suite"
SIEVE_LIMIT = 120000
SIEVE_ROUNDS = 4
MATMUL_N = 64
NBODY_COUNT = 64
NBODY_STEPS = 40
MANDEL_SIZE = 140
MANDEL_ITER = 64
''',
        'math/kernels/sieve.quds':
            '''# Sieve of Eratosthenes — promotes to Tier-1 unboxed Int64List + fused superops
countPrimesRepeated(limit: int, rounds: int) -> int:
  var total = 0
  var r = 0
  while r < rounds:
    var isPrime = List.filled(limit + 1, 1)
    isPrime[0] = 0
    isPrime[1] = 0
    var p = 2
    while p * p <= limit:
      if isPrime[p] == 1:
        var m = p * p
        while m <= limit:
          isPrime[m] = 0
          m = m + p
      p = p + 1
    var c = 0
    var i = 2
    while i <= limit:
      c = c + isPrime[i]
      i = i + 1
    total = total + c
    r = r + 1
  return total
''',
        'math/kernels/matmul.quds':
            '''# Dense Matrix Multiplication O(N^3) — promotes to Tier-1 Float64List + F_MUL_ADD
denseMatMulChecksum(n: int) -> double:
  var a = List.filled(n * n, 0.0)
  var b = List.filled(n * n, 0.0)
  var i = 0
  while i < n:
    var j = 0
    while j < n:
      a[i * n + j] = ((i * 3 + j * 7) % 19) * 0.25
      b[i * n + j] = ((i * 5 + j * 2) % 17) * 0.25
      j = j + 1
    i = i + 1
  var total = 0.0
  i = 0
  while i < n:
    var j = 0
    while j < n:
      var acc = 0.0
      var k = 0
      while k < n:
        acc = acc + a[i * n + k] * b[k * n + j]
        k = k + 1
      total = total + acc
      j = j + 1
    i = i + 1
  return total
''',
        'math/kernels/nbody.quds':
            '''# Gravitational N-Body Simulation O(N^2 * steps) — Tier-1 F_INV_SQRT + F_CUBE + F_MUL_ADD
use dart:math as m

nbodyEnergy(n: int, steps: int) -> double:
  var px = List.filled(n, 0.0)
  var py = List.filled(n, 0.0)
  var vx = List.filled(n, 0.0)
  var vy = List.filled(n, 0.0)
  var i = 0
  while i < n:
    px[i] = (i * 0.37) - 10.0
    py[i] = (i * 0.53) - 12.0
    vx[i] = (i % 5 - 2) * 0.01
    vy[i] = (i % 7 - 3) * 0.01
    i = i + 1
  var s = 0
  while s < steps:
    i = 0
    while i < n:
      var ax = 0.0
      var ay = 0.0
      var j = 0
      while j < n:
        if i != j:
          dx = px[j] - px[i]
          dy = py[j] - py[i]
          d2 = dx * dx + dy * dy + 0.05
          inv = 1.0 / m.sqrt(d2)
          f = inv * inv * inv * 0.001
          ax = ax + dx * f
          ay = ay + dy * f
        j = j + 1
      vx[i] = vx[i] + ax
      vy[i] = vy[i] + ay
      i = i + 1
    i = 0
    while i < n:
      px[i] = px[i] + vx[i]
      py[i] = py[i] + vy[i]
      i = i + 1
    s = s + 1
  var energy = 0.0
  i = 0
  while i < n:
    energy = energy + px[i] * px[i] + py[i] * py[i]
    i = i + 1
  return energy
''',
        'math/kernels/mandelbrot.quds':
            '''# Mandelbrot Escape-Time Fractal — promotes to Tier-1 F_SQR_SUM + F_MUL2_ADD
mandelbrotChecksum(size: int, maxIter: int) -> int:
  var total = 0
  var py = 0
  while py < size:
    cy = (py / size) * 2.4 - 1.2
    var px = 0
    while px < size:
      cx = (px / size) * 3.0 - 2.1
      var zr = 0.0
      var zi = 0.0
      var it = 0
      while it < maxIter:
        zr2 = zr * zr
        zi2 = zi * zi
        if zr2 + zi2 > 4.0:
          break
        zi = 2.0 * zr * zi + cy
        zr = zr2 - zi2 + cx
        it = it + 1
      total = total + it
      px = px + 1
    py = py + 1
  return total
''',
        'math/index.quds':
            '''# Barrel module re-exporting all 4 heavy compute kernels
export kernels.sieve show countPrimesRepeated
export kernels.matmul show denseMatMulChecksum
export kernels.nbody show nbodyEnergy
export kernels.mandelbrot show mandelbrotChecksum
''',
        'domain/report/summary.quds':
            '''# Formats verified checksums from all 4 heavy kernels
use ^^.core.config.workload show SUITE_LABEL, SIEVE_LIMIT, SIEVE_ROUNDS, MATMUL_N, NBODY_COUNT, NBODY_STEPS, MANDEL_SIZE, MANDEL_ITER

buildReportLine(primes: int, matSum: double, energy: double, mandel: int) -> String:
  return "{SUITE_LABEL} | Sieve({SIEVE_LIMIT}x{SIEVE_ROUNDS})={primes} | MatMul({MATMUL_N}x{MATMUL_N})={matSum.toStringAsFixed(2)} | NBody({NBODY_COUNT}x{NBODY_STEPS})={energy.toStringAsFixed(2)} | Mandel({MANDEL_SIZE}x{MANDEL_ITER})={mandel}"
''',
        'main.quds':
            '''# Entry point for Heavy Multi-Folder VM & Compiled Bytecode Benchmark
use quds:viz as viz
use core.config.workload show SUITE_LABEL, SIEVE_LIMIT, SIEVE_ROUNDS, MATMUL_N, NBODY_COUNT, NBODY_STEPS, MANDEL_SIZE, MANDEL_ITER
use math.index as kernels
use domain.report.summary show buildReportLine

primes = kernels.countPrimesRepeated(SIEVE_LIMIT, SIEVE_ROUNDS)
matSum = kernels.denseMatMulChecksum(MATMUL_N)
energy = kernels.nbodyEnergy(NBODY_COUNT, NBODY_STEPS)
mandel = kernels.mandelbrotChecksum(MANDEL_SIZE, MANDEL_ITER)

rows = [
  ["Sieve of Eratosthenes", "math/kernels/sieve.quds", "{SIEVE_LIMIT} x {SIEVE_ROUNDS}", "{primes}"],
  ["Dense MatMul O(N^3)", "math/kernels/matmul.quds", "{MATMUL_N} x {MATMUL_N}", "{matSum.toStringAsFixed(2)}"],
  ["N-Body Gravity", "math/kernels/nbody.quds", "{NBODY_COUNT} bodies x {NBODY_STEPS}", "{energy.toStringAsFixed(2)}"],
  ["Mandelbrot Fractal", "math/kernels/mandelbrot.quds", "{MANDEL_SIZE}x{MANDEL_SIZE}x{MANDEL_ITER}", "{mandel}"],
]

viz.table(
  ["الخوارزمية / Kernel", "الملف / File", "الحجم / Size", "Checksum"],
  rows,
  title: "⚡ {SUITE_LABEL} — Verified Checksums",
)

print buildReportLine(primes, matSum, energy, mandel)
''',
      },
    );

/// All 6 multi-folder Quds project templates ready to switch in 1 tap.
final List<StudioProjectTemplate> studioProjectTemplates = [
  StudioProjectTemplate(
    id: 'orbital_lab',
    nameAr: 'المختبر الفيزيائي',
    nameEn: 'Orbital Lab',
    subtitleAr: '4 مجلدات + assets/planets.json',
    subtitleEn: '4 folders + assets/planets.json',
    icon: Icons.rocket_launch_rounded,
    accentColor: const Color(0xFF38BDF8),
    builder: buildOrbitalLabProject,
  ),
  StudioProjectTemplate(
    id: 'quds_shop_pos',
    nameAr: 'متجر ونقطة بيع POS',
    nameEn: 'Quds Shop POS',
    subtitleAr: 'JSON + CSV + صورة BMP + حفظ الفاتورة',
    subtitleEn: 'JSON + CSV + BMP banner + receipt',
    icon: Icons.point_of_sale_rounded,
    accentColor: const Color(0xFF10B981),
    builder: buildQudsShopPosProject,
  ),
  StudioProjectTemplate(
    id: 'heavy_vm_lab',
    nameAr: 'مختبر الأداء والملفات المترجمة',
    nameEn: 'Heavy VM & Compiled Lab',
    subtitleAr: '5 مجلدات + 4 خوارزميات ثقيلة (AST / Bytecode / مترجم)',
    subtitleEn: '5 folders + 4 heavy kernels (AST / Bytecode / Compiled)',
    icon: Icons.speed_rounded,
    accentColor: const Color(0xFFF97316),
    builder: buildHeavyVmLabProject,
    usesBenchmarkPolicy: true,
  ),
  StudioProjectTemplate(
    id: 'sales_analytics_hub',
    nameAr: 'تحليلات المبيعات',
    nameEn: 'Sales Analytics',
    subtitleAr: 'مجلد analytics/ + CSV + JSON + رسوم',
    subtitleEn: 'analytics/ + CSV + JSON + charts',
    icon: Icons.query_stats_rounded,
    accentColor: const Color(0xFF8B5CF6),
    builder: buildSalesAnalyticsHubProject,
  ),
  StudioProjectTemplate(
    id: 'quds_extensions_host',
    nameAr: 'نظام الإضافات (Extensions)',
    nameEn: 'Extensions Host',
    subtitleAr: 'مضيف معزول + 3 إضافات + plugins.json',
    subtitleEn: 'Sandboxed host + 3 plugins + JSON',
    icon: Icons.extension_rounded,
    accentColor: const Color(0xFFF59E0B),
    builder: buildExtensionsHostProject,
  ),
  StudioProjectTemplate(
    id: 'pixel_asset_studio',
    nameAr: 'استوديو الصور BMP',
    nameEn: 'Pixel Asset Studio',
    subtitleAr: 'صورة ثنائية logo.bmp + لوحات JSON',
    subtitleEn: 'Binary logo.bmp + JSON palettes',
    icon: Icons.palette_rounded,
    accentColor: const Color(0xFFEC4899),
    builder: buildPixelAssetStudioProject,
  ),
];
