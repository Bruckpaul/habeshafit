import 'dart:math';

final _rand = Random();

/// Short unique id: `<prefix>_<time base36><random base36>`.
String newId(String prefix) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = _rand.nextInt(1 << 30).toRadixString(36);
  return '${prefix}_$t$r';
}

/// Date-only key like `2026-11-05`, used to compare calendar days.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
