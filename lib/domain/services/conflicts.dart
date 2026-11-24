/// Timetable conflict detection.
library;

class Slot {
  final String id;
  final int weekday; // ISO 1…7
  final int start; // minutes after midnight
  final int end;
  const Slot(this.id, this.weekday, this.start, this.end);
}

/// Two half-open intervals [aStart, aEnd) and [bStart, bEnd) overlap.
bool overlaps(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && bStart < aEnd;

/// Minutes two slots share (0 when they do not overlap or are on other days).
int overlapMinutes(Slot a, Slot b) {
  if (a.weekday != b.weekday) return 0;
  final s = a.start > b.start ? a.start : b.start;
  final e = a.end < b.end ? a.end : b.end;
  return e > s ? e - s : 0;
}

/// Every pair of slots that overlap (each pair once, in input order).
List<(Slot, Slot)> findConflicts(List<Slot> slots) {
  final out = <(Slot, Slot)>[];
  final byDay = <int, List<Slot>>{};
  for (final s in slots) {
    byDay.putIfAbsent(s.weekday, () => []).add(s);
  }
  for (final day in byDay.values) {
    day.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 0; i < day.length; i++) {
      for (var j = i + 1; j < day.length && day[j].start < day[i].end; j++) {
        if (overlaps(day[i].start, day[i].end, day[j].start, day[j].end)) out.add((day[i], day[j]));
      }
    }
  }
  return out;
}

/// Existing slots a candidate would clash with (the candidate's own id is skipped,
/// so editing a session does not clash with itself).
List<Slot> conflictsWith(Slot candidate, List<Slot> existing) => [
  for (final s in existing)
    if (s.id != candidate.id && s.weekday == candidate.weekday && overlaps(candidate.start, candidate.end, s.start, s.end)) s,
];

/// Clashing timed items (e.g. two exams) given absolute start/end times.
List<(T, T)> findTimeClashes<T>(List<T> items, DateTime Function(T) start, DateTime Function(T) end) {
  final sorted = [...items]..sort((a, b) => start(a).compareTo(start(b)));
  final out = <(T, T)>[];
  for (var i = 0; i < sorted.length; i++) {
    for (var j = i + 1; j < sorted.length && start(sorted[j]).isBefore(end(sorted[i])); j++) {
      out.add((sorted[i], sorted[j]));
    }
  }
  return out;
}
