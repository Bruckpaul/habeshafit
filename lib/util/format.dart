import 'package:intl/intl.dart';

import '../models/profile.dart';

const double _lbPerKg = 2.2046226218;

double kgToDisplay(double kg, WeightUnit u) => u == WeightUnit.kg ? kg : kg * _lbPerKg;
double displayToKg(double v, WeightUnit u) => u == WeightUnit.kg ? v : v / _lbPerKg;

/// `80`, `82.5`, `176.4` — at most one decimal, no trailing zero.
String fmtNumber(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}

String fmtWeight(double kg, WeightUnit u, {bool withUnit = true}) {
  final s = fmtNumber(kgToDisplay(kg, u));
  return withUnit ? '$s ${u.name}' : s;
}

/// Total volume, compact: `8,450 kg`, `12.3k kg`.
String fmtVolume(double kg, WeightUnit u) {
  final v = kgToDisplay(kg, u);
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k ${u.name}';
  return '${NumberFormat.decimalPattern().format(v.round())} ${u.name}';
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${d.inMinutes}m';
}

/// Live clock: `12:05` or `1:02:05`.
String fmtClock(Duration d) {
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}

String fmtRest(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60, s = seconds % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

String capitalize(String s) =>
    s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// "Today", "Yesterday", "3 days ago", or a date.
String relativeDay(DateTime d, DateTime now) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return '$days days ago';
  if (days == -1) return 'Tomorrow';
  if (days < -1 && days > -7) return DateFormat('EEEE').format(d);
  return DateFormat('MMM d').format(d);
}

/// `1 exercise`, `3 exercises`, `1 title`.
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
