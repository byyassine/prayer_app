import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'habous_parser.dart';
import 'repository.dart';
import 'notification_service.dart';

// ══════════════ المهام الخلفية ══════════════
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationService.init();
      if (task == 'reschedule_after_boot') {
        // بعد إعادة تشغيل الهاتف: إعادة برمجة إشعارات الشهر من الكاش
        await NotificationService.rescheduleFromCache();
      } else if (task == 'habous_fetch') {
        // تحديث كل 48 ساعة من موقع الوزارة
        if (await Repository.isStale()) {
          final d = await Repository.fetchAndSave();
          if (d != null) await NotificationService.scheduleMonth(d);
        }
      }
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'habous_fetch',
    'habous_fetch',
    frequency: const Duration(hours: 12), // فحص كل 12س، الجلب الفعلي عند >48س
    constraints: Constraints(networkType: NetworkType.connected),
    existingPeriodicWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(const PrayerApp());
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مواقيت الصلاة',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const PrayerHome(),
      );
}

// ══════════════ الشاشة الرئيسية ══════════════
const _prayers = [
  ('fajr', 'الفجر'), ('chourouq', 'الشروق'), ('dhuhr', 'الظهر'),
  ('asr', 'العصر'), ('maghrib', 'المغرب'), ('isha', 'العشاء'),
];
const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'ماي', 'يونيو',
    'يوليوز', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر'];

class PrayerHome extends StatefulWidget {
  const PrayerHome({super.key});
  @override
  State<PrayerHome> createState() => _PrayerHomeState();
}

class _PrayerHomeState extends State<PrayerHome> {
  HabousData? data;
  PrayerDay? selected;
  int fetchedAt = 0;
  bool fromCache = false;
  bool loading = true;
  String? error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _boot();
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    final c = await Repository.load();
    if (c != null) {
      if (!mounted) return;
      setState(() {
        data = c.data;
        fetchedAt = c.fetchedAt;
        fromCache = c.stale;
        selected = _todayRow(c.data) ?? c.data.days.first;
        loading = false;
      });
      if (c.stale) _refresh();
    } else {
      await _refresh();
    }
  }

  PrayerDay? _todayRow(HabousData d) {
    final t = DateTime.now();
    for (final r in d.days) {
      if (r.date.year == t.year && r.date.month == t.month && r.date.day == t.day) return r;
    }
    return null;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    final d = await Repository.fetchAndSave();
    if (!mounted) return;
    if (d != null) {
      await NotificationService.scheduleMonth(d);
      setState(() {
        data = d;
        fetchedAt = DateTime.now().millisecondsSinceEpoch;
        fromCache = false;
        selected = _todayRow(d) ?? d.days.first;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
        fromCache = true;
        if (data == null) error = 'تعذر جلب البيانات من موقع الوزارة حالياً. حاول لاحقاً.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // السماء
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF030B1F), Color(0xFF0A1A3A), Color(0xFF16294D),
                   Color(0xFF2A3A5F), Color(0xFF4A3B63)],
        ))),
        const Positioned.fill(child: _Stars()),
        const Positioned(top: 50, left: 40, child: _Moon()),
        // المسجد
        Align(alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.26,
            child: CustomPaint(painter: MosquePainter()),
          ),
        ),
        // المحتوى
        SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFFFFD97A),
            backgroundColor: const Color(0xFF0A1428),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _buildCard(context),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(BuildContext context) {
    final d = data;
    if (loading && d == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD97A))),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(child: Text('⚠️ $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 16))),
      );
    }
    if (d == null || selected == null) return const SizedBox.shrink();

    final sel = selected!;
    final isToday = _isToday(sel);
    final upd = DateTime.fromMillisecondsSinceEpoch(fetchedAt);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x8C0A1428),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(children: [
        Text('🕌 مواقيت الصلاة${d.ville.isNotEmpty ? ' — ${d.ville}' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: Color(0xFFFFD97A))),
        const SizedBox(height: 4),
        Text('المصدر: وزارة الأوقاف والشؤون الإسلامية — habous.gov.ma',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.6))),
        Text('آخر تحديث: ${_two(upd.day)}/${_two(upd.month)}/${upd.year} - ${_two(upd.hour)}:${_two(upd.minute)}${fromCache ? ' (من الذاكرة المؤقتة)' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF7EE8FA))),
        const SizedBox(height: 16),

        // التاريخان
        Row(children: [
          Expanded(child: _dateBox('📅 التاريخ الميلادي',
              '${_weekdays[sel.date.weekday - 1]} ${sel.date.day} ${_months[sel.date.month - 1]} ${sel.date.year}')),
          const SizedBox(width: 10),
          Expanded(child: _dateBox('🌙 التاريخ الهجري',
              d.hijriMonth.isNotEmpty ? '${sel.hijri} ${d.hijriMonth}' : sel.hijri)),
        ]),
        const SizedBox(height: 16),

        _dayTabs(d),
        const SizedBox(height: 16),

        // العد التنازلي
        Text(isToday ? '📿 الوقت المتبقي لصلاة ${_nextPrayerName(sel) ?? '—'}'
                     : '📿 مواقيت يوم ${_weekdays[sel.date.weekday - 1]}',
            style: const TextStyle(fontSize: 17, color: Color(0xFF7EE8FA))),
        const SizedBox(height: 6),
        Text(isToday ? _countdownText(sel) : '--:--:--',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold,
                letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 16),

        // شبكة الصلوات
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 480 ? 6 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            for (final p in _prayers)
              _prayerTile(sel, p.$1, p.$2, isToday),
          ],
        ),
        const SizedBox(height: 14),
        Text('يتم تحديث البيانات تلقائياً من موقع الوزارة كل 48 ساعة، اعداد ياسين',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(.5))),
      ]),
    );
  }

  bool _isToday(PrayerDay r) {
    final t = DateTime.now();
    return r.date.year == t.year && r.date.month == t.month && r.date.day == t.day;
  }

  Widget _dateBox(String lbl, String val) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.35),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: [
      Text(lbl, style: const TextStyle(fontSize: 11, color: Color(0xFF8EC5FF))),
      const SizedBox(height: 6),
      Text(val, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _dayTabs(HabousData d) {
    final t = DateTime.now();
    final tabs = d.days.where((r) {
      final diff = r.date.difference(DateTime(t.year, t.month, t.day)).inDays;
      return diff >= -3 && diff <= 3;
    }).toList();
    return Wrap(
      spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
      children: [
        for (final r in tabs)
          GestureDetector(
            onTap: () => setState(() => selected = r),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: r == selected
                    ? const Color(0x33FFD97A)
                    : Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: r == selected
                    ? const Color(0xFFFFD97A) : Colors.white24),
              ),
              child: Column(children: [
                Text('${r.date.day}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD97A))),
                Text(_relLabel(r.date),
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(.8))),
              ]),
            ),
          ),
      ],
    );
  }

  String _relLabel(DateTime date) {
    final t = DateTime.now();
    final diff = date.difference(DateTime(t.year, t.month, t.day)).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == -1) return 'أمس';
    if (diff == 1) return 'غداً';
    if (diff < 0) return 'قبل ${-diff}';
    return 'بعد $diff';
  }

  Widget _prayerTile(PrayerDay r, String key, String name, bool isToday) {
    final now = DateTime.now();
    final hm = r.byKey(key);
    final h = int.parse(hm.substring(0, 2)), m = int.parse(hm.substring(3, 5));
    final t = DateTime(r.date.year, r.date.month, r.date.day, h, m);
    final isNext = isToday && _nextPrayerKey(r) == key;
    final passed = isToday && !isNext && !t.isAfter(now);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isNext ? const Color(0x2E7EE8FA) : Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNext ? const Color(0xFF7EE8FA) : Colors.transparent),
      ),
      child: Opacity(
        opacity: passed ? .45 : 1,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
          Text(hm, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: isNext ? const Color(0xFF7EE8FA) : Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }

  String? _nextPrayerKey(PrayerDay r) {
    final now = DateTime.now();
    for (final p in _prayers) {
      if (p.$1 == 'chourouq') continue; // الشروق يُعرض ولا يُحتسب
      final hm = r.byKey(p.$1);
      final h = int.parse(hm.substring(0, 2)), m = int.parse(hm.substring(3, 5));
      final t = DateTime(r.date.year, r.date.month, r.date.day, h, m);
      if (t.isAfter(now)) return p.$1;
    }
    return null;
  }

  String? _nextPrayerName(PrayerDay r) {
    final k = _nextPrayerKey(r);
    if (k == null) return 'الفجر (غداً)';
    for (final p in _prayers) { if (p.$1 == k) return p.$2; }
    return null;
  }

  String _countdownText(PrayerDay r) {
    final now = DateTime.now();
    DateTime? target;
    for (final p in _prayers) {
      if (p.$1 == 'chourouq') continue;
      final hm = r.byKey(p.$1);
      final h = int.parse(hm.substring(0, 2)), m = int.parse(hm.substring(3, 5));
      var t = DateTime(r.date.year, r.date.month, r.date.day, h, m);
      if (!t.isAfter(now)) {
        if (p.$1 == 'isha') {
          t = t.add(const Duration(days: 1)); // انتهت صلوات اليوم → الفجر غداً
          target = t; break;
        }
        continue;
      }
      target = t; break;
    }
    if (target == null) return '--:--:--';
    final diff = target.difference(now);
    return '${_two(diff.inHours)}:${_two(diff.inMinutes % 60)}:${_two(diff.inSeconds % 60)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

// ══════════════ النجوم ══════════════
class _Stars extends StatefulWidget {
  const _Stars();
  @override
  State<_Stars> createState() => _StarsState();
}

class _StarsState extends State<_Stars> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  final rnd = Random(42);
  late final List<_Star> stars = List.generate(70, (_) => _Star(
    x: rnd.nextDouble(), y: rnd.nextDouble() * .6,
    size: 1 + rnd.nextDouble() * 2.2,
    phase: rnd.nextDouble(), dur: 2 + rnd.nextDouble() * 3,
  ));

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() { c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, __) => Stack(children: [
      for (final s in stars)
        Positioned(
          left: s.x * MediaQuery.of(context).size.width,
          top: s.y * MediaQuery.of(context).size.height,
          child: Opacity(
            opacity: .2 + .8 * (.5 + .5 * sin(2 * pi * (c.value / s.dur * 4 + s.phase))),
            child: Container(width: s.size, height: s.size,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ),
        ),
    ]),
  );
}

class _Star {
  final double x, y, size, phase, dur;
  _Star({required this.x, required this.y, required this.size, required this.phase, required this.dur});
}

// ══════════════ القمر ══════════════
class _Moon extends StatelessWidget {
  const _Moon();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(80, 80), painter: _MoonPainter());
}

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.saveLayer(Rect.largest, Paint());
    canvas.drawCircle(Offset(r, r), r * .8, Paint()..color = const Color(0xFFFFE9A8));
    canvas.drawCircle(Offset(r - r * .45, r - r * .25), r * .72,
        Paint()..color = Colors.black..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawCircle(Offset(r, r), r * .8,
        Paint()..color = const Color(0x33FFE9A8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════ المسجد (نفس SVG ديال الويب) ══════════════
class MosquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1200, size.height / 260);

    final p1 = Path()
      ..moveTo(0, 260)..lineTo(0, 200)..lineTo(60, 200)..lineTo(60, 120)..lineTo(70, 120)
      ..lineTo(70, 100)..lineTo(75, 80)..lineTo(80, 100)..lineTo(80, 120)..lineTo(90, 120)
      ..lineTo(90, 200)..lineTo(150, 200)..lineTo(150, 160)
      ..quadraticBezierTo(225, 60, 300, 160)..lineTo(300, 200)..lineTo(330, 200)
      ..lineTo(330, 140)..lineTo(340, 140)..lineTo(340, 115)..lineTo(345, 90)..lineTo(350, 115)
      ..lineTo(350, 140)..lineTo(360, 140)..lineTo(360, 200)..lineTo(420, 200)
      ..quadraticBezierTo(600, 20, 780, 200)..lineTo(840, 200)..lineTo(840, 130)
      ..lineTo(850, 130)..lineTo(850, 105)..lineTo(855, 80)..lineTo(860, 105)..lineTo(860, 130)
      ..lineTo(870, 130)..lineTo(870, 200)..lineTo(930, 200)..lineTo(930, 160)
      ..quadraticBezierTo(1005, 70, 1080, 160)..lineTo(1080, 200)..lineTo(1200, 200)
      ..lineTo(1200, 260)..close();
    canvas.drawPath(p1, Paint()..color = const Color(0xFF060B18));

    final p2 = Path()
      ..moveTo(0, 260)..lineTo(0, 230)
      ..quadraticBezierTo(200, 205, 400, 230)
      ..quadraticBezierTo(600, 255, 800, 230)
      ..quadraticBezierTo(1000, 205, 1200, 230)
      ..lineTo(1200, 260)..close();
    canvas.drawPath(p2, Paint()..color = const Color(0xFF0A1226));

    canvas.restore();
  }
  @override bool shouldRepaint(_) => false;
}
