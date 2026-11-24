import '../../core/utils/time.dart';
import 'academic.dart';

enum Repeat { none, daily, weekly }

/// Which reminders the student wants, and how early.
class ReminderPrefs {
  final bool lectures, assignments, exams, projects, study, events, dailySummary, weeklySummary;
  final int lectureLeadMin, assignmentLeadMin, examLeadMin, projectLeadMin;
  final int dailyAtMin; // minutes after midnight
  const ReminderPrefs({
    this.lectures = true,
    this.assignments = true,
    this.exams = true,
    this.projects = true,
    this.study = true,
    this.events = true,
    this.dailySummary = true,
    this.weeklySummary = true,
    this.lectureLeadMin = 15,
    this.assignmentLeadMin = 24 * 60,
    this.examLeadMin = 24 * 60,
    this.projectLeadMin = 24 * 60,
    this.dailyAtMin = 7 * 60,
  });
}

class PlannedReminder {
  final int id;
  final DateTime when;
  final String title, body;
  final Repeat repeat;
  const PlannedReminder(this.id, this.when, this.title, this.body, {this.repeat = Repeat.none});
}

/// Stable 31-bit notification id for (kind, row id, slot).
int reminderId(String kind, String id, [int slot = 0]) {
  var h = 0x811c9dc5;
  for (final c in '$kind:$id:$slot'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h;
}

typedef Tr = String Function(String key, [Map<String, String> args]);

/// Every reminder to schedule from the student's real data.
/// Weekly lecture reminders repeat; one-off reminders in the past are skipped.
List<PlannedReminder> planReminders(Academic a, ReminderPrefs p, DateTime now, Tr tr, {int horizonDays = 60}) {
  final out = <PlannedReminder>[];
  final limit = now.add(Duration(days: horizonDays));
  void once(String kind, String id, DateTime? at, int leadMin, String title, String body, [int slot = 0]) {
    if (at == null) return;
    final when = at.subtract(Duration(minutes: leadMin));
    if (!when.isAfter(now) || when.isAfter(limit)) return;
    out.add(PlannedReminder(reminderId(kind, id, slot), when, title, body));
  }

  if (p.lectures) {
    for (final s in a.sessions) {
      final c = a.course(s.courseId);
      if (c == null || c.archived || c.status != 'ongoing') continue;
      final lead = s.reminderMin ?? p.lectureLeadMin;
      // next occurrence of this weekday at start - lead
      var day = dayOnly(now);
      DateTime? when;
      for (var i = 0; i < 8; i++) {
        final d = DateTime(day.year, day.month, day.day + i);
        if (d.weekday != s.weekday) continue;
        final w = d.add(Duration(minutes: s.startMin - lead));
        if (w.isAfter(now)) {
          when = w;
          break;
        }
      }
      if (when == null) continue;
      out.add(
        PlannedReminder(
          reminderId('lecture', s.id),
          when,
          tr('rem_lecture', {'course': c.name}),
          tr('rem_lecture_body', {'time': hhmm(s.startMin), 'room': s.room.isEmpty ? '—' : s.room}),
          repeat: Repeat.weekly,
        ),
      );
    }
  }
  if (p.assignments) {
    for (final x in a.openAssignments(now)) {
      final lead = x.reminderMin ?? p.assignmentLeadMin;
      once('assignment', x.id, x.dueAt, lead, tr('rem_assignment', {'title': x.title}), tr('rem_due_at', {'when': _fmt(x.dueAt!)}));
      // a second nudge one hour before
      if (lead > 60) once('assignment', x.id, x.dueAt, 60, tr('rem_assignment_soon', {'title': x.title}), tr('rem_due_at', {'when': _fmt(x.dueAt!)}), 1);
    }
  }
  if (p.exams) {
    for (final e in a.upcomingExams(now)) {
      once(
        'exam',
        e.id,
        e.startsAt,
        e.reminderMin ?? p.examLeadMin,
        tr('rem_exam', {'title': e.title}),
        tr('rem_exam_body', {'when': _fmt(e.startsAt!), 'place': e.location.isEmpty ? '—' : e.location}),
      );
      once('exam', e.id, e.startsAt, 60, tr('rem_exam', {'title': e.title}), tr('rem_exam_hour'), 1);
    }
  }
  if (p.projects) {
    for (final pr in a.activeProjects) {
      if (pr.dueOn == null) continue;
      once(
        'project',
        pr.id,
        DateTime(pr.dueOn!.year, pr.dueOn!.month, pr.dueOn!.day, 9),
        p.projectLeadMin,
        tr('rem_project', {'title': pr.title}),
        tr('rem_project_body', {'progress': '${a.projectProgress(pr)}'}),
      );
    }
  }
  if (p.study) {
    for (final s in a.study) {
      if (s.done || s.startMin == null) continue;
      final at = DateTime(s.plannedOn.year, s.plannedOn.month, s.plannedOn.day).add(Duration(minutes: s.startMin!));
      once(
        'study',
        s.id,
        at,
        5,
        tr('rem_study', {'title': s.title.isEmpty ? (a.course(s.courseId)?.name ?? '') : s.title}),
        tr('rem_study_body', {'min': '${s.plannedMin}'}),
      );
    }
  }
  if (p.events) {
    for (final e in a.events) {
      if (e.allDay) continue;
      once('event', e.id, e.startsAt, e.reminderMin ?? 30, e.title, e.location);
    }
  }
  if (p.dailySummary) {
    var at = dayOnly(now).add(Duration(minutes: p.dailyAtMin));
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    out.add(PlannedReminder(reminderId('daily', 'summary'), at, tr('rem_daily'), tr('rem_daily_body'), repeat: Repeat.daily));
  }
  if (p.weeklySummary) {
    var at = weekStartOf(now, a.profile.weekStart).add(const Duration(hours: 8));
    while (!at.isAfter(now)) {
      at = DateTime(at.year, at.month, at.day + 7, 8);
    }
    out.add(PlannedReminder(reminderId('weekly', 'summary'), at, tr('rem_weekly'), tr('rem_weekly_body'), repeat: Repeat.weekly));
  }
  return out;
}

String _fmt(DateTime t) => '${dateKey(t)} ${hhmm(minutesOf(t))}';
