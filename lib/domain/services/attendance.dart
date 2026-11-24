/// Attendance and absence-limit math.
///
/// Rules (all configurable per profile / course):
/// * `late` counts as attended, but every [latePerAbsence] lates add one absence
///   (0 = lates never count as absences).
/// * `excused` absences do not count against the limit and are left out of the rate.
/// * The allowed absences are `floor(totalLectures × limitPct / 100)`; going ABOVE that
///   number crosses the limit (many universities bar the student from the final exam).
library;

enum AbsenceRisk { safe, warning, exceeded, unknown }

class AttendanceStats {
  final int present, absent, late, excused;
  final int latePerAbsence;
  final int totalLectures; // planned lectures in the term (0 = unknown)
  final double limitPct;

  const AttendanceStats({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    this.latePerAbsence = 3,
    this.totalLectures = 0,
    this.limitPct = 25,
  });

  factory AttendanceStats.fromStatuses(Iterable<String> statuses, {int latePerAbsence = 3, int totalLectures = 0, double limitPct = 25}) {
    var p = 0, a = 0, l = 0, e = 0;
    for (final s in statuses) {
      switch (s) {
        case 'present':
          p++;
        case 'absent':
          a++;
        case 'late':
          l++;
        case 'excused':
          e++;
      }
    }
    return AttendanceStats(present: p, absent: a, late: l, excused: e, latePerAbsence: latePerAbsence, totalLectures: totalLectures, limitPct: limitPct);
  }

  /// Lectures recorded (all statuses).
  int get recorded => present + absent + late + excused;

  /// Lectures that count for the rate (excused left out).
  int get counted => present + absent + late;

  /// Absences that count against the limit (absent + lates converted).
  int get effectiveAbsences => absent + (latePerAbsence > 0 ? late ~/ latePerAbsence : 0);

  /// Attendance rate in percent of counted lectures (null before any record).
  double? get attendanceRate => counted == 0 ? null : (counted - effectiveAbsences) * 100 / counted;

  /// Absences allowed in the whole term (null when the number of lectures is unknown).
  int? get maxAllowed => totalLectures <= 0 ? null : (totalLectures * limitPct / 100 + 1e-9).floor();

  /// How many more absences can be taken without crossing the limit (negative = crossed).
  int? get remainingAllowed => maxAllowed == null ? null : maxAllowed! - effectiveAbsences;

  /// Absence rate against the whole term, in percent (null when unknown).
  double? get absenceRateOfTerm => totalLectures <= 0 ? null : effectiveAbsences * 100 / totalLectures;

  /// Lectures still to come in the term (null when unknown).
  int? get lecturesLeft => totalLectures <= 0 ? null : (totalLectures - recorded).clamp(0, totalLectures);

  AbsenceRisk get risk {
    final max = maxAllowed;
    if (max == null) return AbsenceRisk.unknown;
    if (effectiveAbsences > max) return AbsenceRisk.exceeded;
    final left = max - effectiveAbsences;
    if (left <= 1 || (max > 0 && effectiveAbsences * 4 >= max * 3)) return AbsenceRisk.warning;
    return AbsenceRisk.safe;
  }
}

/// Estimated lectures in a term: each weekly session meets once per week between
/// [start] and [end] (inclusive). [weekdays] are ISO weekdays (1 = Mon … 7 = Sun),
/// one entry per weekly session.
int estimateLectures(List<int> weekdays, DateTime start, DateTime end) {
  if (end.isBefore(start)) return 0;
  var n = 0;
  final days = DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  for (var i = 0; i <= days; i++) {
    final wd = DateTime(start.year, start.month, start.day + i).weekday;
    for (final w in weekdays) {
      if (w == wd) n++;
    }
  }
  return n;
}
