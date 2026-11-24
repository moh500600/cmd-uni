import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uni_planner/core/errors/app_exception.dart';
import 'package:uni_planner/core/utils/time.dart';
import 'package:uni_planner/data/db/app_database.dart';
import 'package:uni_planner/data/db/local_store.dart';
import 'package:uni_planner/data/repositories/uni_repository.dart';
import 'package:uni_planner/domain/entities/entities.dart';
import 'package:uni_planner/domain/services/study_planner.dart';

Future<UniRepository> repo() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
  await AppDatabase.create(db);
  return UniRepository(LocalStore(db), '22222222-2222-4222-8222-222222222222');
}

void main() {
  final today = dayOnly(DateTime.now());
  DateTime d(int n, [int h = 0]) => DateTime(today.year, today.month, today.day + n, h);

  test('re-marking attendance for the same day updates it instead of duplicating', () async {
    final r = await repo();
    final c = await r.save('courses', {'name': 'DS', 'credit_hours': '3', 'total_lectures': 20});
    await r.markAttendance(c, d(-1), 'absent');
    await r.markAttendance(c, d(-1), 'excused');
    await r.markAttendance(c, d(-2), 'late');
    final a = await r.load();
    expect(a.attendance.length, 2);
    expect(a.attendance.firstWhere((x) => dateKey(x.onDate) == dateKey(d(-1))).status, 'excused');
  });

  test('a score above the maximum is rejected; an exam score lands once in the grade book', () async {
    final r = await repo();
    final c = await r.save('courses', {'name': 'DB', 'credit_hours': '3'});
    await expectLater(r.save('grade_items', {'course_id': c, 'title': 'Q', 'score': '11', 'max_score': '10'}), throwsA(isA<AppException>()));
    final e = await r.save('exams', {'course_id': c, 'title': 'Mid', 'kind': 'midterm', 'starts_at': isoUtc(d(-1))});
    await r.recordScore(courseId: c, title: 'Mid', category: 'midterm', score: '25.5', max: '30', sourceKind: 'exam', sourceId: e);
    await r.recordScore(courseId: c, title: 'Mid', category: 'midterm', score: '26', max: '30', sourceKind: 'exam', sourceId: e);
    final a = await r.load();
    expect(a.grades.length, 1);
    expect(a.grades.single.score.toString(), '26');
  });

  test('completing an assignment stamps submission and 100% progress', () async {
    final r = await repo();
    final id = await r.save('assignments', {'title': 'HW', 'due_at': isoUtc(d(2))});
    var a = await r.load();
    await r.setAssignmentStatus(a.assignments.single, 'completed');
    a = await r.load();
    expect(a.assignments.single.submittedAt, isNotNull);
    expect(a.progressOf(a.assignments.single), 100);
    expect(a.openAssignments(DateTime.now()).where((x) => x.id == id), isEmpty);
  });

  test('the smart plan spreads open exam topics over the days before the exam', () async {
    final r = await repo();
    final c = await r.save('courses', {'name': 'Stats', 'credit_hours': '3'});
    await r.save('exams', {
      'course_id': c,
      'title': 'Midterm',
      'kind': 'midterm',
      'starts_at': isoUtc(d(3, 10)),
      'topics': Exam.encodeTopics([ExamTopic('A', true), ExamTopic('B', false), ExamTopic('C', false), ExamTopic('D', false), ExamTopic('E', false)]),
    });
    final plan = suggestExamPlan(await r.load(), DateTime.now(), maxPerDay: 2);
    expect(plan.map((p) => p.title), unorderedEquals(['B', 'C', 'D', 'E'])); // done topic skipped
    for (final p in plan) {
      expect(p.day.isBefore(d(3)), isTrue, reason: 'all study before exam day');
      expect(!p.day.isBefore(today), isTrue);
    }
    final perDay = <String, int>{};
    for (final p in plan) {
      perDay[dateKey(p.day)] = (perDay[dateKey(p.day)] ?? 0) + 1;
    }
    expect(perDay.values.every((n) => n <= 2), isTrue);
    expect(perDay.length, 3); // used all three days
  });

  test('weekly attendance rate is a percent and the study streak counts back from today', () async {
    final r = await repo();
    final c = await r.save('courses', {'name': 'Net', 'credit_hours': '3'});
    await r.markAttendance(c, today, 'present');
    await r.markAttendance(c, today, 'absent', sessionId: 's2');
    for (var i = 0; i < 3; i++) {
      await r.save('study_sessions', {'planned_on': dateKey(d(-i)), 'planned_min': 30, 'actual_min': 30, 'done': true});
    }
    await r.save('study_sessions', {'planned_on': dateKey(d(-5)), 'planned_min': 30, 'actual_min': 30});
    final a = await r.load();
    expect(a.weekly(DateTime.now()).attendanceRate, 50);
    expect(a.studyStreak, 3);
  });
}
