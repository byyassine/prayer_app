import 'package:html/parser.dart' as html_parser;

/// يوم واحد من جدول الوزارة
class PrayerDay {
  final int gDay;
  final int? gMonth;
  final int? gYear;
  final String hijri;
  final String fajr, chourouq, dhuhr, asr, maghrib, isha;

  const PrayerDay.full({
    required this.gDay,
    this.gMonth,
    this.gYear,
    required this.hijri,
    required this.fajr,
    required this.chourouq,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerDay.fromJson(Map<String, dynamic> j) => PrayerDay.full(
        gDay: j['gDay'],
        gMonth: j['gMonth'],
        gYear: j['gYear'],
        hijri: j['hijri'],
        fajr: j['fajr'],
        chourouq: j['chourouq'],
        dhuhr: j['dhuhr'],
        asr: j['asr'],
        maghrib: j['maghrib'],
        isha: j['isha'],
      );

  Map<String, dynamic> toJson() => {
        'gDay': gDay, 'gMonth': gMonth, 'gYear': gYear, 'hijri': hijri,
        'fajr': fajr, 'chourouq': chourouq, 'dhuhr': dhuhr,
        'asr': asr, 'maghrib': maghrib, 'isha': isha,
      };

  String byKey(String k) => {
        'fajr': fajr, 'chourouq': chourouq, 'dhuhr': dhuhr,
        'asr': asr, 'maghrib': maghrib, 'isha': isha,
      }[k]!;

  /// التاريخ الميلادي الكامل (مع fallback إذا الجدول ما فيهوش الشهر/السنة)
  DateTime get date {
    final now = DateTime.now();
    return DateTime(gYear ?? now.year, gMonth ?? now.month, gDay);
  }
}

class HabousData {
  final String ville;
  final String hijriMonth;
  final List<PrayerDay> days;
  const HabousData({required this.ville, required this.hijriMonth, required this.days});
}

/// نفس منطق الـ PHP ديالك بالضبط — نفس الجدول = نفس الدقة
HabousData? parseHabous(String html) {
  final doc = html_parser.parse(html);

  String ville = '';
  final opts = doc.querySelectorAll('select option[selected]');
  for (final o in opts) {
    ville = o.text.trim();
    if (ville.isNotEmpty) break;
  }

  const jours = [
    'السبت','الأحد','الاحد','الإثنين','الاثنين','الاتنين','الأثنين','الثلاثاء','التلاتاء',
    'الأربعاء','الاربعاء','الخميس','الجمعة','الجمعاء',
    'Samedi','Dimanche','Lundi','Mardi','Mercredi','Jeudi','Vendredi',
  ];

  String hijriMonth = '';
  final days = <PrayerDay>[];

  for (final tr in doc.querySelectorAll('tr')) {
    final cells = tr
        .querySelectorAll('th,td')
        .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    if (cells.length < 9) continue;

    // ترويسة الجدول: نلتقط اسم الشهر الهجري من العمود الثاني
    if (hijriMonth.isEmpty &&
        RegExp(r'[\u0600-\u06FFA-Za-z]').hasMatch(cells[1]) &&
        !RegExp(r'^\d+$').hasMatch(cells[1]) &&
        !cells[0].toLowerCase().contains('jour') &&
        !cells[0].contains('اليوم')) {
      hijriMonth = cells[1];
      continue;
    }

    final isDay = jours.any((j) => cells[0].toLowerCase().contains(j.toLowerCase()));
    if (!isDay) continue;
    if (!RegExp(r'^\d{1,2}:\d{2}').hasMatch(cells[3])) continue;

    // استخراج اليوم (والشهر/السنة إذا كان التاريخ كاملاً مثل 12/09/2026)
    int gDay = 0;
    int? gMonth, gYear;
    final full = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})').firstMatch(cells[2]);
    if (full != null) {
      gDay = int.parse(full.group(1)!);
      gMonth = int.parse(full.group(2)!);
      gYear = int.parse(full.group(3)!);
    } else {
      final d = RegExp(r'\d{1,2}').firstMatch(cells[2]);
      if (d == null) continue;
      gDay = int.parse(d.group(0)!);
    }

    days.add(PrayerDay.full(
      gDay: gDay, gMonth: gMonth, gYear: gYear,
      hijri: cells[1],
      fajr: cells[3].substring(0, 5),
      chourouq: cells[4].substring(0, 5),
      dhuhr: cells[5].substring(0, 5),
      asr: cells[6].substring(0, 5),
      maghrib: cells[7].substring(0, 5),
      isha: cells[8].substring(0, 5),
    ));
  }

  if (days.isEmpty) return null;
  return HabousData(ville: ville, hijriMonth: hijriMonth, days: days);
}
