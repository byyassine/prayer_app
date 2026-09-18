import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'habous_parser.dart';

class CachedData {
  final HabousData data;
  final int fetchedAt;
  final bool stale; // صحيح = البيانات أقدم من 48 ساعة
  const CachedData({required this.data, required this.fetchedAt, required this.stale});
}

class Repository {
  static const int ville = 117; // ← رمز مدينتك في موقع الوزارة
  static const String sourceUrl =
      'https://www.habous.gov.ma/prieres/horaire_hijri_2.php?ville=$ville';
  static const Duration cacheTtl = Duration(hours: 48);

  static const _kRows = 'rows_v1';
  static const _kMonth = 'hijri_month_v1';
  static const _kVille = 'ville_v1';
  static const _kFetched = 'fetched_at_v1';

  static Future<CachedData?> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kRows);
    if (s == null) return null;
    try {
      final rows = (jsonDecode(s) as List)
          .map((e) => PrayerDay.fromJson(e as Map<String, dynamic>))
          .toList();
      final fetchedAt = p.getInt(_kFetched) ?? 0;
      final stale = DateTime.now().millisecondsSinceEpoch - fetchedAt >
          cacheTtl.inMilliseconds;
      return CachedData(
        data: HabousData(
          ville: p.getString(_kVille) ?? '',
          hijriMonth: p.getString(_kMonth) ?? '',
          days: rows,
        ),
        fetchedAt: fetchedAt,
        stale: stale,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isStale() async {
    final p = await SharedPreferences.getInstance();
    final f = p.getInt(_kFetched) ?? 0;
    return DateTime.now().millisecondsSinceEpoch - f > cacheTtl.inMilliseconds;
  }

  /// جلب من موقع الوزارة + تخزين محلياً. يرجع null عند الفشل (يبقى الكاش القديم).
  static Future<HabousData?> fetchAndSave() async {
    try {
      final res = await http.get(
        Uri.parse(sourceUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept-Language': 'ar,fr;q=0.9',
        },
      ).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;

      final data = parseHabous(res.body);
      if (data == null || data.days.isEmpty) return null;

      final p = await SharedPreferences.getInstance();
      await p.setString(_kRows, jsonEncode(data.days.map((e) => e.toJson()).toList()));
      await p.setString(_kMonth, data.hijriMonth);
      await p.setString(_kVille, data.ville);
      await p.setInt(_kFetched, DateTime.now().millisecondsSinceEpoch);
      return data;
    } catch (_) {
      return null;
    }
  }
}
