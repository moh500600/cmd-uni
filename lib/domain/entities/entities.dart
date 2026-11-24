import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../core/utils/time.dart';

typedef DbRow = Map<String, Object?>;

String _s(DbRow r, String k) => (r[k] as String?) ?? '';
String? _sn(DbRow r, String k) {
  final v = r[k] as String?;
  return v == null || v.isEmpty ? null : v;
}

int _i(DbRow r, String k, [int d = 0]) => (r[k] as num?)?.toInt() ?? d;
int? _in(DbRow r, String k) => (r[k] as num?)?.toInt();
bool _b(DbRow r, String k) => r[k] == 1 || r[k] == true;
Decimal? _dn(DbRow r, String k) => r[k] == null ? null : Decimal.tryParse(r[k].toString());
Decimal _d(DbRow r, String k, [String d = '0']) => _dn(r, k) ?? Decimal.parse(d);
DateTime? _ts(DbRow r, String k) => parseIso(r[k] as String?);
DateTime? _date(DbRow r, String k) => parseDate(r[k] as String?);

/// Splits a multi-line text field into non-empty trimmed lines.
List<String> lines(String s) => s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

abstract class Entity {
  final String id;
  final DateTime? createdAt, updatedAt;
  Entity(DbRow r) : id = r['id'] as String, createdAt = _ts(r, 'created_at'), updatedAt = _ts(r, 'updated_at');
}

class Profile extends Entity {
  final String fullName, studentNumber, university, college, department, major, level, academicYear;
  final String? currentTermId;
  final Decimal priorHours;
  final Decimal? priorGpa;
  final String gpaSystem; // '4' | '5' | '100'
  final String gradeScale; // JSON or ''
  final int latePerAbsence;
  final Decimal absenceLimitPct;
  final int weekStart;
  Profile(super.r)
    : fullName = _s(r, 'full_name'),
      studentNumber = _s(r, 'student_number'),
      university = _s(r, 'university'),
      college = _s(r, 'college'),
      department = _s(r, 'department'),
      major = _s(r, 'major'),
      level = _s(r, 'level'),
      academicYear = _s(r, 'academic_year'),
      currentTermId = _sn(r, 'current_term_id'),
      priorHours = _d(r, 'prior_hours'),
      priorGpa = _dn(r, 'prior_gpa'),
      gpaSystem = _sn(r, 'gpa_system') ?? '4',
      gradeScale = _s(r, 'grade_scale'),
      latePerAbsence = _i(r, 'late_per_absence', 3),
      absenceLimitPct = _d(r, 'absence_limit_pct', '25'),
      weekStart = _i(r, 'week_start', 6);

  /// An empty profile for a student who has not filled it yet.
  static Profile empty(String uid) => Profile({'id': uid});
}

class Term extends Entity {
  final String name, notes;
  final DateTime? startDate, endDate;
  final int position;
  Term(super.r)
    : name = _s(r, 'name'),
      notes = _s(r, 'notes'),
      startDate = _date(r, 'start_date'),
      endDate = _date(r, 'end_date'),
      position = _i(r, 'position');
}

class Course extends Entity {
  final String? termId;
  final String name, code, instructor, department, description, referencesText, links, status;
  final Decimal creditHours;
  final int color;
  final bool archived, includeInGpa;
  final int totalLectures;
  final Decimal? absenceLimitPct, finalPercent;
  final String? finalLetter;
  Course(super.r)
    : termId = _sn(r, 'term_id'),
      name = _s(r, 'name'),
      code = _s(r, 'code'),
      instructor = _s(r, 'instructor'),
      department = _s(r, 'department'),
      description = _s(r, 'description'),
      referencesText = _s(r, 'references_text'),
      links = _s(r, 'links'),
      status = _sn(r, 'status') ?? 'ongoing',
      creditHours = _d(r, 'credit_hours', '3'),
      color = _i(r, 'color'),
      archived = _b(r, 'archived'),
      includeInGpa = r['include_in_gpa'] == null ? true : _b(r, 'include_in_gpa'),
      totalLectures = _i(r, 'total_lectures'),
      absenceLimitPct = _dn(r, 'absence_limit_pct'),
      finalPercent = _dn(r, 'final_percent'),
      finalLetter = _sn(r, 'final_letter');
  String get label => code.isEmpty ? name : '$code · $name';
}

class CourseUnit extends Entity {
  final String courseId, title;
  final int position, difficulty;
  final bool done;
  CourseUnit(super.r)
    : courseId = _s(r, 'course_id'),
      title = _s(r, 'title'),
      position = _i(r, 'position'),
      difficulty = _i(r, 'difficulty', 2),
      done = _b(r, 'done');
}

class ClassSession extends Entity {
  final String courseId, room, instructor, kind, mode, link;
  final int weekday, startMin, endMin;
  final int? reminderMin;
  ClassSession(super.r)
    : courseId = _s(r, 'course_id'),
      room = _s(r, 'room'),
      instructor = _s(r, 'instructor'),
      kind = _sn(r, 'kind') ?? 'lecture',
      mode = _sn(r, 'mode') ?? 'in_person',
      link = _s(r, 'link'),
      weekday = _i(r, 'weekday', 1),
      startMin = _i(r, 'start_min'),
      endMin = _i(r, 'end_min'),
      reminderMin = _in(r, 'reminder_min');
  bool get online => mode == 'online';
}

const kAssignmentStatuses = ['not_started', 'in_progress', 'completed', 'submitted', 'late', 'cancelled'];

class Assignment extends Entity {
  final String? courseId;
  final String title, description, status, links, solutionNote;
  final DateTime? assignedOn, dueAt, submittedAt;
  final int priority, progress;
  final Decimal? maxGrade, score;
  final int? reminderMin;
  Assignment(super.r)
    : courseId = _sn(r, 'course_id'),
      title = _s(r, 'title'),
      description = _s(r, 'description'),
      status = _sn(r, 'status') ?? 'not_started',
      links = _s(r, 'links'),
      solutionNote = _s(r, 'solution_note'),
      assignedOn = _date(r, 'assigned_on'),
      dueAt = _ts(r, 'due_at'),
      submittedAt = _ts(r, 'submitted_at'),
      priority = _i(r, 'priority', 1),
      progress = _i(r, 'progress'),
      maxGrade = _dn(r, 'max_grade'),
      score = _dn(r, 'score'),
      reminderMin = _in(r, 'reminder_min');
}

const kExamKinds = ['quiz', 'monthly', 'midterm', 'final', 'practical', 'oral'];

class ExamTopic {
  final String title;
  final bool done;
  const ExamTopic(this.title, this.done);
  Map<String, Object> toJson() => {'t': title, 'd': done};
}

class Exam extends Entity {
  final String? courseId;
  final String title, kind, location, notes;
  final DateTime? startsAt;
  final int durationMin;
  final Decimal? maxGrade, score;
  final List<ExamTopic> topics;
  final int? reminderMin;
  Exam(super.r)
    : courseId = _sn(r, 'course_id'),
      title = _s(r, 'title'),
      kind = _sn(r, 'kind') ?? 'quiz',
      location = _s(r, 'location'),
      notes = _s(r, 'notes'),
      startsAt = _ts(r, 'starts_at'),
      durationMin = _i(r, 'duration_min', 60),
      maxGrade = _dn(r, 'max_grade'),
      score = _dn(r, 'score'),
      topics = decodeTopics(_s(r, 'topics')),
      reminderMin = _in(r, 'reminder_min');

  static List<ExamTopic> decodeTopics(String s) {
    if (s.trim().isEmpty) return const [];
    try {
      final l = jsonDecode(s) as List;
      return [for (final e in l) ExamTopic((e as Map)['t']?.toString() ?? '', e['d'] == true)];
    } catch (_) {
      return [for (final t in lines(s)) ExamTopic(t, false)];
    }
  }

  static String encodeTopics(List<ExamTopic> t) => jsonEncode([for (final e in t) e.toJson()]);
  bool get finished => score != null;
}

const kProjectStatuses = ['planning', 'active', 'review', 'done', 'cancelled'];

class Project extends Entity {
  final String? courseId;
  final String title, description, supervisor, team, status;
  final bool isGroup;
  final DateTime? startOn, dueOn;
  Project(super.r)
    : courseId = _sn(r, 'course_id'),
      title = _s(r, 'title'),
      description = _s(r, 'description'),
      supervisor = _s(r, 'supervisor'),
      team = _s(r, 'team'),
      status = _sn(r, 'status') ?? 'active',
      isGroup = _b(r, 'is_group'),
      startOn = _date(r, 'start_on'),
      dueOn = _date(r, 'due_on');
  List<String> get members => lines(team);
}

class ProjectPhase extends Entity {
  final String projectId, title;
  final DateTime? dueOn;
  final int position;
  final bool done;
  ProjectPhase(super.r)
    : projectId = _s(r, 'project_id'),
      title = _s(r, 'title'),
      dueOn = _date(r, 'due_on'),
      position = _i(r, 'position'),
      done = _b(r, 'done');
}

class Subtask extends Entity {
  final String parentKind, parentId, title, assignee;
  final String? phaseId;
  final DateTime? dueOn;
  final bool done;
  final int position;
  Subtask(super.r)
    : parentKind = _s(r, 'parent_kind'),
      parentId = _s(r, 'parent_id'),
      title = _s(r, 'title'),
      assignee = _s(r, 'assignee'),
      phaseId = _sn(r, 'phase_id'),
      dueOn = _date(r, 'due_on'),
      done = _b(r, 'done'),
      position = _i(r, 'position');
}

const kGradeCategories = ['quiz', 'exam', 'midterm', 'final', 'assignment', 'participation', 'project', 'lab', 'other'];

class GradeItem extends Entity {
  final String courseId, category, title;
  final Decimal score, maxScore;
  final Decimal? weight;
  final DateTime? gradedOn;
  final String? sourceKind, sourceId;
  GradeItem(super.r)
    : courseId = _s(r, 'course_id'),
      category = _sn(r, 'category') ?? 'exam',
      title = _s(r, 'title'),
      score = _d(r, 'score'),
      maxScore = _d(r, 'max_score', '100'),
      weight = _dn(r, 'weight'),
      gradedOn = _date(r, 'graded_on'),
      sourceKind = _sn(r, 'source_kind'),
      sourceId = _sn(r, 'source_id');
}

const kAttendanceStatuses = ['present', 'absent', 'late', 'excused'];

class AttendanceRecord extends Entity {
  final String courseId, status, note;
  final String? sessionId;
  final DateTime onDate;
  AttendanceRecord(super.r)
    : courseId = _s(r, 'course_id'),
      status = _sn(r, 'status') ?? 'present',
      note = _s(r, 'note'),
      sessionId = _sn(r, 'session_id'),
      onDate = _date(r, 'on_date') ?? DateTime(2000);
}

class Note extends Entity {
  final String? courseId;
  final String title, lectureTitle, body, keyPoints, summary, category, links;
  final DateTime? lectureOn;
  final bool pinned, archived;
  Note(super.r)
    : courseId = _sn(r, 'course_id'),
      title = _s(r, 'title'),
      lectureTitle = _s(r, 'lecture_title'),
      body = _s(r, 'body'),
      keyPoints = _s(r, 'key_points'),
      summary = _s(r, 'summary'),
      category = _s(r, 'category'),
      links = _s(r, 'links'),
      lectureOn = _date(r, 'lecture_on'),
      pinned = _b(r, 'pinned'),
      archived = _b(r, 'archived');
}

const kResourceCategories = ['book', 'lecture', 'handout', 'summary', 'research', 'project', 'exam_sample', 'other'];
const kFileTypes = ['pdf', 'word', 'ppt', 'excel', 'image', 'audio', 'link', 'other'];

class Resource extends Entity {
  final String? courseId, storagePath, ownerKind, ownerId;
  final String title, category, fileType, fileName, url, notes;
  final int sizeBytes;
  Resource(super.r)
    : courseId = _sn(r, 'course_id'),
      storagePath = _sn(r, 'storage_path'),
      ownerKind = _sn(r, 'owner_kind'),
      ownerId = _sn(r, 'owner_id'),
      title = _s(r, 'title'),
      category = _sn(r, 'category') ?? 'other',
      fileType = _sn(r, 'file_type') ?? 'other',
      fileName = _s(r, 'file_name'),
      url = _s(r, 'url'),
      notes = _s(r, 'notes'),
      sizeBytes = _i(r, 'size_bytes');
  bool get isLink => fileType == 'link';
}

class StudySession extends Entity {
  final String? courseId, unitId;
  final String title, source, notes;
  final DateTime plannedOn;
  final int? startMin;
  final int plannedMin, actualMin, difficulty;
  final bool done;
  StudySession(super.r)
    : courseId = _sn(r, 'course_id'),
      unitId = _sn(r, 'unit_id'),
      title = _s(r, 'title'),
      source = _sn(r, 'source') ?? 'plan',
      notes = _s(r, 'notes'),
      plannedOn = _date(r, 'planned_on') ?? DateTime(2000),
      startMin = _in(r, 'start_min'),
      plannedMin = _i(r, 'planned_min'),
      actualMin = _i(r, 'actual_min'),
      difficulty = _i(r, 'difficulty', 2),
      done = _b(r, 'done');
}

const kEventKinds = ['meeting', 'event', 'deadline', 'other'];

class CalEvent extends Entity {
  final String? courseId;
  final String title, kind, location, notes;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final int? reminderMin;
  CalEvent(super.r)
    : courseId = _sn(r, 'course_id'),
      title = _s(r, 'title'),
      kind = _sn(r, 'kind') ?? 'event',
      location = _s(r, 'location'),
      notes = _s(r, 'notes'),
      startsAt = _ts(r, 'starts_at') ?? DateTime(2000),
      endsAt = _ts(r, 'ends_at'),
      allDay = _b(r, 'all_day'),
      reminderMin = _in(r, 'reminder_min');
}

class ActivityEntry extends Entity {
  final String entityKind, action, detail;
  final String? entityId;
  ActivityEntry(super.r) : entityKind = _s(r, 'entity_kind'), action = _s(r, 'action'), detail = _s(r, 'detail'), entityId = _sn(r, 'entity_id');
}
