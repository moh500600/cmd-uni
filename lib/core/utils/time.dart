/// Date / time helpers shared by the database, sync and UI.
///
/// * Timestamps are stored as fixed-width UTC ISO strings
///   `YYYY-MM-DDTHH:MM:SS.mmmZ`, so text order == time order (sync relies on it).
/// * Dates (no time) are stored as `YYYY-MM-DD`.
/// * Times of day are minutes after midnight (0…1439).
library;

String _two(int n) => n.toString().padLeft(2, '0');
String _three(int n) => n.toString().padLeft(3, '0');

/// Fixed-width UTC ISO timestamp (millisecond precision).
String isoUtc(DateTime t) {
  final u = t.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${_two(u.month)}-${_two(u.day)}T${_two(u.hour)}:${_two(u.minute)}:${_two(u.second)}.${_three(u.millisecond)}Z';
}

/// Parses any ISO timestamp (server or local) and re-normalises it.
String? normalizeIso(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  final t = DateTime.tryParse(s);
  return t == null ? null : isoUtc(t);
}

DateTime? parseIso(String? s) => s == null || s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();

String nowIso() => isoUtc(DateTime.now());

/// `YYYY-MM-DD` for the local calendar day of [t].
String dateKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';

DateTime? parseDate(String? s) {
  if (s == null || s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4)), m = int.tryParse(s.substring(5, 7)), d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime dayOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Whole calendar days from [from] to [to] (local days, DST-safe).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// `HH:MM` for minutes after midnight.
String hhmm(int minutes) => '${_two((minutes ~/ 60) % 24)}:${_two(minutes % 60)}';

int minutesOf(DateTime t) => t.hour * 60 + t.minute;

/// The date of the given ISO weekday (1 = Monday … 7 = Sunday) in the week of [ref]
/// whose first day is [weekStart].
DateTime weekStartOf(DateTime ref, int weekStart) {
  final d = dayOnly(ref);
  final back = (d.weekday - weekStart + 7) % 7;
  return DateTime(d.year, d.month, d.day - back);
}
