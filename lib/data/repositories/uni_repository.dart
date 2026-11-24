import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/time.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/academic_repository.dart';
import '../../domain/services/academic.dart';
import '../db/local_store.dart';
import '../db/schema.dart';

/// The one write path for the student's data (offline-first: SQLite, then sync).
class UniRepository implements AcademicRepository {
  final LocalStore store;
  final String uid;
  UniRepository(this.store, this.uid);

  Database get db => store.db;

  @override
  Future<Academic> load() async {
    Future<List<DbRow>> q(String t) => store.all(t, uid);
    final profileRow = (await store.all('profiles', uid)).where((r) => r['id'] == uid).firstOrNull ?? (await store.all('profiles', uid)).firstOrNull;
    return Academic(
      uid: uid,
      profile: profileRow == null ? Profile.empty(uid) : Profile(profileRow),
      terms: (await store.all('terms', uid, orderBy: 'position, created_at')).map(Term.new).toList(),
      courses: (await store.all('courses', uid, orderBy: 'name COLLATE NOCASE')).map(Course.new).toList(),
      units: (await q('course_units')).map(CourseUnit.new).toList(),
      sessions: (await store.all('class_sessions', uid, orderBy: 'weekday, start_min')).map(ClassSession.new).toList(),
      assignments: (await q('assignments')).map(Assignment.new).toList(),
      exams: (await q('exams')).map(Exam.new).toList(),
      projects: (await q('projects')).map(Project.new).toList(),
      phases: (await q('project_phases')).map(ProjectPhase.new).toList(),
      subtasks: (await q('subtasks')).map(Subtask.new).toList(),
      grades: (await store.all('grade_items', uid, orderBy: 'graded_on, created_at')).map(GradeItem.new).toList(),
      attendance: (await store.all('attendance', uid, orderBy: 'on_date DESC')).map(AttendanceRecord.new).toList(),
      notes: (await store.all('notes', uid, orderBy: 'pinned DESC, updated_at DESC')).map(Note.new).toList(),
      resources: (await store.all('resources', uid, orderBy: 'created_at DESC')).map(Resource.new).toList(),
      study: (await store.all('study_sessions', uid, orderBy: 'planned_on, start_min')).map(StudySession.new).toList(),
      events: (await store.all('events', uid, orderBy: 'starts_at')).map(CalEvent.new).toList(),
      activity: (await store.all('activity_log', uid, orderBy: 'created_at DESC')).map(ActivityEntry.new).toList(),
    );
  }

  @override
  Future<String> save(String table, Map<String, Object?> row, {String? log}) async {
    _validate(table, row);
    final isNew = row['id'] == null || await store.get(table, row['id'] as String) == null;
    final id = await store.save(table, uid, row);
    if (log != null) await this.log(table, id, isNew ? 'created' : 'updated', log);
    return id;
  }

  @override
  Future<void> delete(String table, String id, {String? log}) async {
    await store.delete(table, id);
    if (log != null) await this.log(table, id, 'deleted', log);
  }

  Future<void> log(String kind, String? id, String action, String detail) =>
      store.save('activity_log', uid, {'entity_kind': kind, 'entity_id': id, 'action': action, 'detail': detail}, notify: false);

  /// Input rules the database also enforces on the server.
  void _validate(String table, Map<String, Object?> row) {
    String? s(String k) => row[k]?.toString();
    bool blank(String k) => row.containsKey(k) && (s(k) ?? '').trim().isEmpty;
    const titled = {
      'terms': 'name',
      'courses': 'name',
      'assignments': 'title',
      'exams': 'title',
      'projects': 'title',
      'project_phases': 'title',
      'subtasks': 'title',
      'grade_items': 'title',
      'notes': 'title',
      'resources': 'title',
      'events': 'title',
      'course_units': 'title',
    };
    final tk = titled[table];
    if (tk != null && (blank(tk) || (row['id'] == null && (s(tk) ?? '').trim().isEmpty))) throw const AppException('v_required');
    if (table == 'class_sessions') {
      final a = row['start_min'] as int?, b = row['end_min'] as int?;
      if (a != null && b != null && b <= a) throw const AppException('err_end_before_start');
    }
    if (table == 'grade_items') {
      final sc = double.tryParse(s('score') ?? ''), mx = double.tryParse(s('max_score') ?? '');
      if (sc == null || mx == null || mx <= 0 || sc < 0) throw const AppException('v_number');
      if (sc > mx) throw const AppException('err_score_above_max');
    }
    if (table == 'events') {
      final a = row['starts_at'] as String?, b = row['ends_at'] as String?;
      if (a != null && b != null && b.compareTo(a) < 0) throw const AppException('err_end_before_start');
    }
  }

  // ------------------------------------------------------------ domain helpers

  /// One attendance record per course + day + session: re-marking updates it (no duplicates).
  Future<String> markAttendance(String courseId, DateTime day, String status, {String? sessionId, String note = ''}) async {
    final existing = await store.all(
      'attendance',
      uid,
      where: 'course_id = ? AND on_date = ? AND IFNULL(session_id, \'\') = ?',
      args: [courseId, dateKey(day), sessionId ?? ''],
    );
    return store.save('attendance', uid, {
      if (existing.isNotEmpty) 'id': existing.first['id'],
      'course_id': courseId,
      'session_id': sessionId,
      'on_date': dateKey(day),
      'status': status,
      'note': note,
    });
  }

  Future<void> setAssignmentStatus(Assignment a, String status) async {
    final row = <String, Object?>{'id': a.id, 'status': status};
    if ((status == 'submitted' || status == 'completed') && a.submittedAt == null) row['submitted_at'] = nowIso();
    if (status == 'completed' || status == 'submitted') row['progress'] = 100;
    if (status == 'not_started') row['progress'] = 0;
    await save('assignments', row, log: '${a.title} → $status');
  }

  Future<void> toggleSubtask(Subtask s) => save('subtasks', {'id': s.id, 'done': !s.done});

  /// Records an exam / assignment score in the course's grade book (one item per source).
  Future<void> recordScore({
    required String courseId,
    required String title,
    required String category,
    required String score,
    required String max,
    String? sourceKind,
    String? sourceId,
  }) async {
    final existing = sourceId == null ? <DbRow>[] : await store.all('grade_items', uid, where: 'source_id = ?', args: [sourceId]);
    await save('grade_items', {
      if (existing.isNotEmpty) 'id': existing.first['id'],
      'course_id': courseId,
      'title': title,
      'category': category,
      'score': score,
      'max_score': max,
      'graded_on': dateKey(DateTime.now()),
      'source_kind': sourceKind,
      'source_id': sourceId,
    });
  }

  /// True when a course with the same code (or name, when no code) already exists in the term.
  Future<bool> courseExists({required String name, required String code, String? termId, String? exceptId}) async {
    final rows = await store.all('courses', uid);
    return rows.any(
      (r) =>
          r['id'] != exceptId &&
          (r['term_id'] as String?) == termId &&
          (code.trim().isNotEmpty
              ? (r['code'] as String? ?? '').trim().toLowerCase() == code.trim().toLowerCase()
              : (r['name'] as String? ?? '').trim().toLowerCase() == name.trim().toLowerCase()),
    );
  }

  /// Every row of this student (for backup / export).
  Future<Map<String, List<DbRow>>> dump() async => {
    for (final t in kTables) t.name: await db.query(t.name, where: 'user_id = ? AND deleted = 0', whereArgs: [uid]),
  };

  /// Restores a backup: rows are re-owned by this student and merged by id
  /// (a newer copy already on the device is kept).
  Future<int> restore(Map<String, dynamic> data) async {
    var n = 0;
    await db.transaction((txn) async {
      for (final t in kTables) {
        final rows = data[t.name];
        if (rows is! List) continue;
        for (final raw in rows) {
          final r = Map<String, Object?>.from(raw as Map);
          final id = r['id'] as String?;
          if (id == null) continue;
          final local = (await txn.query(t.name, where: 'id = ?', whereArgs: [id])).firstOrNull;
          if (local != null && (local['updated_at'] as String).compareTo(r['updated_at'] as String? ?? '') >= 0) continue;
          final clean = <String, Object?>{
            for (final c in t.allCols)
              if (r.containsKey(c.name)) c.name: r[c.name],
          };
          clean['user_id'] = uid;
          if (t.name == 'profiles') clean['id'] = uid;
          clean['dirty'] = 1;
          clean['updated_at'] = store.stamp();
          await txn.insert(t.name, clean, conflictAlgorithm: ConflictAlgorithm.replace);
          n++;
        }
      }
    });
    store.onChange?.call('*');
    return n;
  }
}
