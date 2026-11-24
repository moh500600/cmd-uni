import 'package:decimal/decimal.dart';

import '../../core/utils/time.dart';
import '../entities/entities.dart';
import 'attendance.dart';
import 'conflicts.dart';
import 'gpa.dart';

/// Status shown for an assignment: a stored "not started"/"in progress" turns
/// "late" once the deadline passes.
String effectiveStatus(Assignment a, DateTime now) {
  if ((a.status == 'not_started' || a.status == 'in_progress') && a.dueAt != null && a.dueAt!.isBefore(now)) return 'late';
  return a.status;
}

bool isOpenAssignment(String status) => status == 'not_started' || status == 'in_progress' || status == 'late';

/// Progress of an assignment: from its sub-tasks when it has any, else the stored %.
int assignmentProgress(Assignment a, List<Subtask> subs) {
  if (a.status == 'completed' || a.status == 'submitted') return 100;
  if (subs.isEmpty) return a.progress;
  return (subs.where((s) => s.done).length * 100 / subs.length).round();
}

/// Countdown to [at] from [now] (negative parts never shown).
class Countdown {
  final int days, hours, minutes;
  final bool past;
  const Countdown(this.days, this.hours, this.minutes, this.past);
  factory Countdown.between(DateTime now, DateTime at) {
    final d = at.difference(now);
    if (d.isNegative) return const Countdown(0, 0, 0, true);
    return Countdown(d.inDays, d.inHours % 24, d.inMinutes % 60, false);
  }
}

/// Exam preparation: days left, topics left, suggested topics per day, readiness.
class ExamPrep {
  final int daysLeft; // calendar days until the exam day (0 = today)
  final int topicsTotal, topicsDone;
  const ExamPrep(this.daysLeft, this.topicsTotal, this.topicsDone);
  factory ExamPrep.of(Exam e, DateTime now) =>
      ExamPrep(e.startsAt == null ? 0 : daysBetween(now, e.startsAt!), e.topics.length, e.topics.where((t) => t.done).length);
  int get topicsLeft => topicsTotal - topicsDone;
  double get readiness => topicsTotal == 0 ? 0 : topicsDone / topicsTotal;

  /// Topics to cover each day to finish one day before the exam (at least 1 when any remain).
  int get topicsPerDay {
    if (topicsLeft <= 0) return 0;
    final studyDays = daysLeft - 1 < 1 ? 1 : daysLeft - 1;
    return (topicsLeft / studyDays).ceil();
  }
}

/// One thing on the calendar / agenda.
class AgendaItem {
  final String kind; // lecture exam assignment project study event
  final String refId;
  final String title;
  final String? courseId;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String subtitle;
  final bool done;
  const AgendaItem(this.kind, this.refId, this.title, this.start, {this.courseId, this.end, this.allDay = false, this.subtitle = '', this.done = false});
}

/// Everything the student has, in memory, plus the derived numbers screens show.
class Academic {
  final String uid;
  final Profile profile;
  final List<Term> terms;
  final List<Course> courses;
  final List<CourseUnit> units;
  final List<ClassSession> sessions;
  final List<Assignment> assignments;
  final List<Exam> exams;
  final List<Project> projects;
  final List<ProjectPhase> phases;
  final List<Subtask> subtasks;
  final List<GradeItem> grades;
  final List<AttendanceRecord> attendance;
  final List<Note> notes;
  final List<Resource> resources;
  final List<StudySession> study;
  final List<CalEvent> events;
  final List<ActivityEntry> activity;

  Academic({
    required this.uid,
    required this.profile,
    this.terms = const [],
    this.courses = const [],
    this.units = const [],
    this.sessions = const [],
    this.assignments = const [],
    this.exams = const [],
    this.projects = const [],
    this.phases = const [],
    this.subtasks = const [],
    this.grades = const [],
    this.attendance = const [],
    this.notes = const [],
    this.resources = const [],
    this.study = const [],
    this.events = const [],
    this.activity = const [],
  });

  late final Map<String, Course> courseById = {for (final c in courses) c.id: c};
  late final GradeScale scale = GradeScale.resolve(profile.gpaSystem, profile.gradeScale);
  late final GpaCalculator calc = GpaCalculator(scale);

  Course? course(String? id) => id == null ? null : courseById[id];

  Term? get currentTerm {
    final id = profile.currentTermId;
    if (id != null) {
      for (final t in terms) {
        if (t.id == id) return t;
      }
    }
    if (terms.isEmpty) return null;
    final now = DateTime.now();
    for (final t in terms) {
      if (t.startDate != null && t.endDate != null && !now.isBefore(t.startDate!) && !now.isAfter(t.endDate!.add(const Duration(days: 1)))) return t;
    }
    final sorted = [...terms]..sort((a, b) => b.position.compareTo(a.position));
    return sorted.first;
  }

  /// Courses of the current term (all non-archived ones when there are no terms).
  List<Course> get currentCourses {
    final t = currentTerm;
    return courses.where((c) => !c.archived && c.status != 'withdrawn' && (t == null || c.termId == t.id || c.termId == null)).toList();
  }

  List<Course> get activeCourses => courses.where((c) => !c.archived).toList();

  // ---------------------------------------------------------------- grades
  List<GradeItem> gradesOf(String courseId) => grades.where((g) => g.courseId == courseId).toList();

  CourseTotal totalOf(String courseId) => CourseTotal.of(gradesOf(courseId).map((g) => GradeComponent(g.score, g.maxScore, g.weight)));

  /// The course's percent: the manual final mark when entered, else its grade items.
  Decimal? percentOf(Course c) => c.finalPercent ?? totalOf(c.id).percent;

  CourseResult resultOf(Course c) =>
      CourseResult(id: c.id, hours: c.creditHours, percent: percentOf(c), letterOverride: c.finalLetter, included: c.includeInGpa && c.status != 'withdrawn');

  GradedCourse? gradedOf(Course c) => calc.grade(resultOf(c));

  GpaSummary termGpa(String? termId) => calc.summarize(courses.where((c) => c.termId == termId && c.status != 'withdrawn').map(resultOf));

  /// Cumulative over every course with a result, plus the record before the app.
  GpaSummary get cumulative =>
      calc.summarize(courses.where((c) => c.status != 'withdrawn').map(resultOf), priorHours: profile.priorHours, priorGpa: profile.priorGpa);

  /// Completed hours: hours of courses marked completed and passed, plus prior hours.
  Decimal get completedHours {
    var h = profile.priorHours;
    for (final c in courses) {
      if (c.status != 'completed') continue;
      final g = gradedOf(c);
      if (g == null || g.band.passing) h += c.creditHours;
    }
    return h;
  }

  // ---------------------------------------------------------------- attendance
  AttendanceStats attendanceOf(Course c) {
    final recs = attendance.where((a) => a.courseId == c.id).map((a) => a.status);
    var total = c.totalLectures;
    if (total <= 0) {
      final t = terms.where((t) => t.id == c.termId).firstOrNull;
      if (t?.startDate != null && t?.endDate != null) {
        total = estimateLectures(sessions.where((s) => s.courseId == c.id).map((s) => s.weekday).toList(), t!.startDate!, t.endDate!);
      }
    }
    final pct = (c.absenceLimitPct ?? profile.absenceLimitPct).toDouble();
    return AttendanceStats.fromStatuses(recs, latePerAbsence: profile.latePerAbsence, totalLectures: total, limitPct: pct);
  }

  // ---------------------------------------------------------------- assignments / projects / exams
  List<Subtask> subtasksOf(String parentId) => subtasks.where((s) => s.parentId == parentId).toList()..sort((a, b) => a.position.compareTo(b.position));

  int progressOf(Assignment a) => assignmentProgress(a, subtasksOf(a.id));

  List<Assignment> openAssignments(DateTime now) => assignments.where((a) => isOpenAssignment(effectiveStatus(a, now))).toList()..sort(_byDue);

  List<Assignment> overdue(DateTime now) => assignments.where((a) => effectiveStatus(a, now) == 'late').toList()..sort(_byDue);

  List<Assignment> dueWithin(DateTime now, Duration d) =>
      openAssignments(now).where((a) => a.dueAt != null && !a.dueAt!.isBefore(now) && a.dueAt!.isBefore(now.add(d))).toList();

  static int _byDue(Assignment a, Assignment b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999));

  List<Exam> upcomingExams(DateTime now) =>
      exams.where((e) => e.startsAt != null && e.startsAt!.add(Duration(minutes: e.durationMin)).isAfter(now)).toList()
        ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));

  List<ProjectPhase> phasesOf(String projectId) => phases.where((p) => p.projectId == projectId).toList()..sort((a, b) => a.position.compareTo(b.position));

  /// Project progress: share of team tasks done, else of phases done, else by status.
  int projectProgress(Project p) {
    if (p.status == 'done') return 100;
    final tasks = subtasksOf(p.id);
    if (tasks.isNotEmpty) return (tasks.where((t) => t.done).length * 100 / tasks.length).round();
    final ph = phasesOf(p.id);
    if (ph.isNotEmpty) return (ph.where((t) => t.done).length * 100 / ph.length).round();
    return 0;
  }

  List<Project> get activeProjects => projects.where((p) => p.status != 'done' && p.status != 'cancelled').toList();

  /// Conflicting class sessions (pairs).
  List<(ClassSession, ClassSession)> get timetableConflicts {
    final active = sessions.where((s) => course(s.courseId)?.archived == false).toList();
    final byId = {for (final s in active) s.id: s};
    return [
      for (final (a, b) in findConflicts([for (final s in active) Slot(s.id, s.weekday, s.startMin, s.endMin)])) (byId[a.id]!, byId[b.id]!),
    ];
  }

  // ---------------------------------------------------------------- progress
  /// Share of the current term's work that is done: assignments finished, course
  /// units studied, project tasks done.
  double? get termCompletion {
    final ids = currentCourses.map((c) => c.id).toSet();
    var done = 0, total = 0;
    for (final a in assignments) {
      if (a.status == 'cancelled' || (a.courseId != null && !ids.contains(a.courseId))) continue;
      total++;
      if (a.status == 'completed' || a.status == 'submitted') done++;
    }
    for (final u in units) {
      if (!ids.contains(u.courseId)) continue;
      total++;
      if (u.done) done++;
    }
    for (final p in activeProjects) {
      for (final t in subtasksOf(p.id)) {
        total++;
        if (t.done) done++;
      }
    }
    return total == 0 ? null : done / total;
  }

  // ---------------------------------------------------------------- calendar
  bool _inTerm(Course? c, DateTime day) {
    if (c == null) return false;
    final t = terms.where((t) => t.id == c.termId).firstOrNull;
    if (t == null) return true;
    if (t.startDate != null && day.isBefore(t.startDate!)) return false;
    if (t.endDate != null && day.isAfter(t.endDate!)) return false;
    return true;
  }

  /// Everything on one calendar day, by time.
  List<AgendaItem> agendaOn(DateTime day) {
    final d0 = dayOnly(day);
    final d1 = d0.add(const Duration(days: 1));
    bool on(DateTime? t) => t != null && !t.isBefore(d0) && t.isBefore(d1);
    final out = <AgendaItem>[];
    for (final s in sessions) {
      final c = course(s.courseId);
      if (s.weekday != d0.weekday || c == null || c.archived || c.status == 'withdrawn' || !_inTerm(c, d0)) continue;
      out.add(
        AgendaItem(
          'lecture',
          s.id,
          c.name,
          DateTime(d0.year, d0.month, d0.day).add(Duration(minutes: s.startMin)),
          end: DateTime(d0.year, d0.month, d0.day).add(Duration(minutes: s.endMin)),
          courseId: c.id,
          subtitle: [s.room, if (s.online) 'online'].where((e) => e.isNotEmpty).join(' · '),
        ),
      );
    }
    for (final e in exams) {
      if (on(e.startsAt)) {
        out.add(
          AgendaItem(
            'exam',
            e.id,
            e.title,
            e.startsAt!,
            end: e.startsAt!.add(Duration(minutes: e.durationMin)),
            courseId: e.courseId,
            subtitle: e.location,
            done: e.finished,
          ),
        );
      }
    }
    for (final a in assignments) {
      if (on(a.dueAt) && a.status != 'cancelled') {
        out.add(AgendaItem('assignment', a.id, a.title, a.dueAt!, courseId: a.courseId, done: a.status == 'completed' || a.status == 'submitted'));
      }
    }
    for (final p in projects) {
      if (p.dueOn != null && dayOnly(p.dueOn!) == d0 && p.status != 'cancelled') {
        out.add(AgendaItem('project', p.id, p.title, d0, allDay: true, courseId: p.courseId, done: p.status == 'done'));
      }
      for (final ph in phasesOf(p.id)) {
        if (ph.dueOn != null && dayOnly(ph.dueOn!) == d0) {
          out.add(AgendaItem('project', p.id, '${p.title} — ${ph.title}', d0, allDay: true, courseId: p.courseId, done: ph.done));
        }
      }
    }
    for (final s in study) {
      if (dayOnly(s.plannedOn) == d0) {
        final start = s.startMin == null ? d0 : d0.add(Duration(minutes: s.startMin!));
        out.add(
          AgendaItem(
            'study',
            s.id,
            s.title.isEmpty ? (course(s.courseId)?.name ?? '') : s.title,
            start,
            end: s.startMin == null ? null : start.add(Duration(minutes: s.plannedMin)),
            allDay: s.startMin == null,
            courseId: s.courseId,
            done: s.done,
          ),
        );
      }
    }
    for (final e in events) {
      final end = e.endsAt ?? e.startsAt;
      if (!e.startsAt.isAfter(d1) && !end.isBefore(d0) && (on(e.startsAt) || (e.startsAt.isBefore(d0) && !end.isBefore(d0)))) {
        out.add(AgendaItem('event', e.id, e.title, e.startsAt, end: e.endsAt, allDay: e.allDay, courseId: e.courseId, subtitle: e.location));
      }
    }
    out.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return out;
  }

  // ---------------------------------------------------------------- study
  int studyMinutes(DateTime from, DateTime to) =>
      study.where((s) => !s.plannedOn.isBefore(dayOnly(from)) && s.plannedOn.isBefore(dayOnly(to))).fold(0, (n, s) => n + s.actualMin);

  /// Planned sessions done in the range, as a share of those planned (null if none).
  double? studyAdherence(DateTime from, DateTime to) {
    final planned = study.where((s) => s.source == 'plan' && !s.plannedOn.isBefore(dayOnly(from)) && s.plannedOn.isBefore(dayOnly(to))).toList();
    if (planned.isEmpty) return null;
    return planned.where((s) => s.done).length / planned.length;
  }

  /// Consecutive days up to today with any study time.
  int get studyStreak {
    final days = study.where((s) => s.actualMin > 0).map((s) => dateKey(s.plannedOn)).toSet();
    var d = dayOnly(DateTime.now());
    if (!days.contains(dateKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dateKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  // ---------------------------------------------------------------- weekly summary
  WeeklySummary weekly(DateTime now) {
    final start = weekStartOf(now, profile.weekStart);
    final end = start.add(const Duration(days: 7));
    bool inWeek(DateTime? t) => t != null && !t.isBefore(start) && t.isBefore(end);
    final att = attendance.where((a) => inWeek(a.onDate)).toList();
    final attended = att.where((a) => a.status == 'present' || a.status == 'late').length;
    final counted = att.where((a) => a.status != 'excused').length;
    return WeeklySummary(
      start: start,
      assignmentsDone: assignments.where((a) => (a.status == 'completed' || a.status == 'submitted') && inWeek(a.submittedAt ?? a.updatedAt)).length,
      assignmentsDue: assignments.where((a) => inWeek(a.dueAt) && a.status != 'cancelled').length,
      examsThisWeek: exams.where((e) => inWeek(e.startsAt)).length,
      studyMinutes: studyMinutes(start, end),
      attendanceRate: counted == 0 ? null : attended * 100 / counted, // percent, like AttendanceStats
      overdue: overdue(now).length,
    );
  }
}

class WeeklySummary {
  final DateTime start;
  final int assignmentsDone, assignmentsDue, examsThisWeek, studyMinutes, overdue;
  final double? attendanceRate;
  const WeeklySummary({
    required this.start,
    required this.assignmentsDone,
    required this.assignmentsDue,
    required this.examsThisWeek,
    required this.studyMinutes,
    required this.attendanceRate,
    required this.overdue,
  });
}
