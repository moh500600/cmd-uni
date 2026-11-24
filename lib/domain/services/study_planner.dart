import '../../core/utils/time.dart';
import 'academic.dart';

/// A study session the planner proposes (the student confirms before saving).
class PlannedStudy {
  final String? courseId;
  final String title;
  final DateTime day;
  final int minutes;
  final int difficulty;
  const PlannedStudy(this.courseId, this.title, this.day, this.minutes, this.difficulty);
}

/// Spreads what is left to review before each upcoming exam over the days
/// before it (nearest exams first), at most [maxPerDay] sessions per day,
/// starting [from] (inclusive). Topics come from the exam's checklist, else
/// from the course's unfinished units, else one general review per day.
List<PlannedStudy> suggestExamPlan(Academic a, DateTime from, {int horizonDays = 14, int maxPerDay = 3, int minutes = 50}) {
  final start = dayOnly(from);
  final load = <String, int>{};
  final out = <PlannedStudy>[];
  final exams = a.upcomingExams(from).where((e) => daysBetween(start, e.startsAt!) <= horizonDays).toList();
  for (final e in exams) {
    final daysAvail = daysBetween(start, e.startsAt!); // study days: start … exam day - 1
    if (daysAvail <= 0) continue;
    var topics = e.topics.where((t) => !t.done).map((t) => t.title).toList();
    var diff = 2;
    if (topics.isEmpty) {
      final units = a.units.where((u) => u.courseId == e.courseId && !u.done).toList();
      topics = units.map((u) => u.title).toList();
      if (units.isNotEmpty) diff = units.map((u) => u.difficulty).reduce((x, y) => x > y ? x : y);
    }
    if (topics.isEmpty) topics = [for (var i = 0; i < (daysAvail < 3 ? daysAvail : 3); i++) e.title];
    var d = 0;
    for (final t in topics) {
      // find the next day (cycling over the available days) with room
      var placed = false;
      for (var tries = 0; tries < daysAvail; tries++) {
        final day = DateTime(start.year, start.month, start.day + ((d + tries) % daysAvail));
        final k = dateKey(day);
        if ((load[k] ?? 0) < maxPerDay) {
          load[k] = (load[k] ?? 0) + 1;
          out.add(PlannedStudy(e.courseId, t, day, minutes, diff));
          d = (d + tries + 1) % daysAvail;
          placed = true;
          break;
        }
      }
      if (!placed) break; // no room left before this exam
    }
  }
  out.sort((x, y) => x.day.compareTo(y.day));
  return out;
}
