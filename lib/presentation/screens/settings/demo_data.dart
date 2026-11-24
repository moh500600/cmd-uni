import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../data/repositories/uni_repository.dart';
import '../../../domain/entities/entities.dart';

/// Optional sample term so a new student can see every screen filled in.
/// Only runs when the student taps "load demo data"; core flows never add it.
Future<void> loadDemoData(UniRepository repo, bool ar) async {
  String t(String a, String e) => ar ? a : e;
  final now = DateTime.now();
  final today = dayOnly(now);
  DateTime d(int days, [int h = 0, int m = 0]) => DateTime(today.year, today.month, today.day + days, h, m);

  final prev = await repo.save('terms', {
    'name': t('الفصل الأول 2025/2026', 'Fall 2025/2026'),
    'start_date': dateKey(d(-250)),
    'end_date': dateKey(d(-140)),
    'position': 0,
  });
  final term = await repo.save('terms', {
    'name': t('الفصل الثاني 2025/2026', 'Spring 2025/2026'),
    'start_date': dateKey(d(-35)),
    'end_date': dateKey(d(75)),
    'position': 1,
  });
  final profile = (await repo.load()).profile;
  await repo.save('profiles', {
    'id': repo.uid,
    'current_term_id': term,
    if (profile.fullName.isEmpty) 'full_name': t('طالب تجريبي', 'Demo Student'),
    if (profile.university.isEmpty) 'university': t('جامعة تجريبية', 'Demo University'),
    if (profile.major.isEmpty) 'major': t('هندسة البرمجيات', 'Software Engineering'),
    if (profile.level.isEmpty) 'level': t('المستوى الثالث', 'Level 3'),
  });

  // a finished term so the cumulative GPA and charts have history
  for (final (n, code, h, pct) in [
    (t('تفاضل وتكامل 2', 'Calculus II'), 'MATH202', 3, '88'),
    (t('برمجة كائنية', 'Object-Oriented Programming'), 'CS211', 4, '93'),
    (t('فيزياء عامة', 'General Physics'), 'PHYS101', 3, '76'),
  ]) {
    await repo.save('courses', {
      'term_id': prev,
      'name': n,
      'code': code,
      'credit_hours': '$h',
      'final_percent': pct,
      'status': 'completed',
      'color': _color(code.length),
    });
  }

  final specs = [
    (
      t('هياكل البيانات', 'Data Structures'),
      'CS301',
      t('د. أحمد سالم', 'Dr. Ahmed Salem'),
      3,
      0,
      [(1, 8 * 60, 9 * 60 + 30, 'A-201'), (3, 8 * 60, 9 * 60 + 30, 'A-201')],
    ),
    (
      t('قواعد البيانات', 'Database Systems'),
      'CS340',
      t('د. منى خالد', 'Dr. Mona Khaled'),
      3,
      1,
      [(1, 10 * 60, 11 * 60 + 30, 'B-105'), (3, 10 * 60, 11 * 60 + 30, 'Lab 3')],
    ),
    (
      t('الإحصاء والاحتمالات', 'Probability & Statistics'),
      'STAT210',
      t('د. سامي يوسف', 'Dr. Sami Youssef'),
      3,
      2,
      [(7, 12 * 60, 13 * 60 + 30, 'C-12'), (2, 12 * 60, 13 * 60 + 30, 'C-12')],
    ),
    (t('شبكات الحاسب', 'Computer Networks'), 'CS360', t('د. ليلى حسن', 'Dr. Laila Hassan'), 3, 3, [(6, 9 * 60, 11 * 60, 'D-3')]),
    (t('مهارات الاتصال', 'Communication Skills'), 'ENG150', t('أ. ريم علي', 'Ms. Reem Ali'), 2, 4, [(4, 13 * 60, 14 * 60 + 30, 'E-7')]),
  ];
  final ids = <String>[];
  final sessionIds = <String, String>{};
  for (final (name, code, inst, hours, color, slots) in specs) {
    final c = await repo.save('courses', {
      'term_id': term,
      'name': name,
      'code': code,
      'instructor': inst,
      'credit_hours': '$hours',
      'color': _color(color),
      'total_lectures': slots.length * 15,
    });
    ids.add(c);
    for (final (wd, s, e, room) in slots) {
      sessionIds['$c$wd'] = await repo.save('class_sessions', {'course_id': c, 'weekday': wd, 'start_min': s, 'end_min': e, 'room': room, 'instructor': inst});
    }
    for (final (i, u) in [t('المقدمة', 'Introduction'), t('الوحدة الثانية', 'Unit 2'), t('الوحدة الثالثة', 'Unit 3'), t('مراجعة', 'Review')].indexed) {
      await repo.save('course_units', {'course_id': c, 'title': u, 'position': i, 'difficulty': 1 + i % 3, 'done': i < 2});
    }
  }
  final ds = ids[0], db = ids[1], st = ids[2], net = ids[3];

  // grades so far
  for (final (c, title, cat, s, m, w) in [
    (ds, t('اختبار قصير 1', 'Quiz 1'), 'quiz', '9', '10', '5'),
    (ds, t('الامتحان النصفي', 'Midterm'), 'midterm', '24.5', '30', '30'),
    (db, t('واجب 1', 'Assignment 1'), 'assignment', '18', '20', '10'),
    (db, t('الامتحان النصفي', 'Midterm'), 'midterm', '21', '30', '30'),
    (st, t('اختبار قصير 1', 'Quiz 1'), 'quiz', '7', '10', '10'),
    (net, t('مختبر 1', 'Lab 1'), 'lab', '9.5', '10', '10'),
  ]) {
    await repo.save('grade_items', {'course_id': c, 'title': title, 'category': cat, 'score': s, 'max_score': m, 'weight': w, 'graded_on': dateKey(d(-10))});
  }

  // assignments
  final a1 = await repo.save('assignments', {
    'course_id': ds,
    'title': t('تطبيق شجرة AVL', 'Implement an AVL tree'),
    'description': t('اكتب الإدراج والحذف مع التدوير، وارفع الكود والتقرير.', 'Insertion and deletion with rotations; upload code and a report.'),
    'assigned_on': dateKey(d(-5)),
    'due_at': isoUtc(d(2, 23, 59)),
    'priority': 2,
    'max_grade': '20',
    'status': 'in_progress',
  });
  for (final (i, s) in [t('الإدراج', 'Insertion'), t('الحذف', 'Deletion'), t('الاختبارات', 'Tests'), t('التقرير', 'Report')].indexed) {
    await repo.save('subtasks', {'parent_kind': 'assignment', 'parent_id': a1, 'title': s, 'position': i, 'done': i < 2});
  }
  await repo.save('assignments', {
    'course_id': db,
    'title': t('تصميم مخطط ER', 'ER diagram design'),
    'assigned_on': dateKey(d(-3)),
    'due_at': isoUtc(d(5, 12)),
    'priority': 1,
    'max_grade': '10',
  });
  await repo.save('assignments', {
    'course_id': st,
    'title': t('ورقة تمارين 3', 'Problem set 3'),
    'assigned_on': dateKey(d(-9)),
    'due_at': isoUtc(d(-1, 23, 59)),
    'priority': 2,
    'status': 'in_progress',
    'progress': 60,
  });
  await repo.save('assignments', {
    'course_id': net,
    'title': t('تقرير مختبر Wireshark', 'Wireshark lab report'),
    'assigned_on': dateKey(d(-12)),
    'due_at': isoUtc(d(-4, 23)),
    'status': 'submitted',
    'submitted_at': isoUtc(d(-5, 20)),
    'progress': 100,
    'max_grade': '10',
    'score': '9',
  });

  // exams
  await repo.save('exams', {
    'course_id': db,
    'title': t('اختبار SQL', 'SQL quiz'),
    'kind': 'quiz',
    'starts_at': isoUtc(d(4, 10)),
    'duration_min': 45,
    'location': 'B-105',
    'max_grade': '10',
    'topics': Exam.encodeTopics([ExamTopic('SELECT / JOIN', true), ExamTopic('GROUP BY', false), ExamTopic(t('الاستعلامات الفرعية', 'Subqueries'), false)]),
  });
  await repo.save('exams', {
    'course_id': st,
    'title': t('الامتحان النصفي', 'Midterm exam'),
    'kind': 'midterm',
    'starts_at': isoUtc(d(9, 12)),
    'duration_min': 90,
    'location': 'C-12',
    'max_grade': '30',
    'topics': Exam.encodeTopics([
      ExamTopic(t('الاحتمال الشرطي', 'Conditional probability'), true),
      ExamTopic(t('المتغيرات العشوائية', 'Random variables'), false),
      ExamTopic(t('التوزيع الطبيعي', 'Normal distribution'), false),
      ExamTopic(t('التوزيع ذو الحدين', 'Binomial distribution'), false),
    ]),
  });

  // attendance (last three weeks)
  final rnd = [0, 0, 0, 1, 0, 2, 0, 0, 3, 0, 0, 1];
  var k = 0;
  for (var back = 21; back >= 1; back--) {
    final day = d(-back);
    for (final (ci, c) in ids.indexed) {
      final wd = specs[ci].$6.map((s) => s.$1);
      if (!wd.contains(day.weekday)) continue;
      final s = kAttendanceStatuses[rnd[k++ % rnd.length]];
      await repo.markAttendance(c, day, s, sessionId: sessionIds['$c${day.weekday}']);
    }
  }

  // a group project
  final p = await repo.save('projects', {
    'course_id': db,
    'title': t('نظام إدارة مكتبة', 'Library management system'),
    'description': t('مشروع جماعي: قاعدة بيانات + واجهة ويب.', 'Team project: database plus a web front end.'),
    'supervisor': t('د. منى خالد', 'Dr. Mona Khaled'),
    'team': t('أنا\nسارة\nعمر', 'Me\nSara\nOmar'),
    'is_group': true,
    'start_on': dateKey(d(-20)),
    'due_on': dateKey(d(30)),
    'status': 'active',
  });
  final ph1 = await repo.save('project_phases', {
    'project_id': p,
    'title': t('التحليل والتصميم', 'Analysis & design'),
    'due_on': dateKey(d(-5)),
    'position': 0,
    'done': true,
  });
  final ph2 = await repo.save('project_phases', {'project_id': p, 'title': t('التنفيذ', 'Implementation'), 'due_on': dateKey(d(20)), 'position': 1});
  for (final (i, title, who, ph, done) in [
    (0, t('مخطط ER', 'ER diagram'), t('أنا', 'Me'), ph1, true),
    (1, t('إنشاء الجداول', 'Create tables'), t('سارة', 'Sara'), ph2, true),
    (2, t('واجهة البحث', 'Search UI'), t('عمر', 'Omar'), ph2, false),
    (3, t('تقرير نهائي', 'Final report'), t('أنا', 'Me'), ph2, false),
  ]) {
    await repo.save('subtasks', {'parent_kind': 'project', 'parent_id': p, 'phase_id': ph, 'title': title, 'assignee': who, 'position': i, 'done': done});
  }

  // notes
  await repo.save('notes', {
    'course_id': ds,
    'title': t('ملخص الأشجار المتوازنة', 'Balanced trees summary'),
    'lecture_title': 'AVL / Red-Black',
    'lecture_on': dateKey(d(-6)),
    'body': t(
      'عامل التوازن = ارتفاع اليسار − ارتفاع اليمين، ويجب أن يكون بين −1 و 1.',
      'Balance factor = height(left) − height(right), must stay within −1..1.',
    ),
    'key_points': t('التدوير الأيمن\nالتدوير الأيسر\nالتدوير المزدوج', 'Right rotation\nLeft rotation\nDouble rotation'),
    'category': t('مراجعة', 'review'),
    'pinned': true,
  });
  await repo.save('notes', {
    'course_id': db,
    'title': t('أنواع الربط JOIN', 'JOIN types'),
    'lecture_on': dateKey(d(-2)),
    'body': 'INNER, LEFT, RIGHT, FULL OUTER',
    'category': 'SQL',
  });

  // study log for the past week and plan for the next days
  for (var back = 6; back >= 0; back--) {
    await repo.save('study_sessions', {
      'course_id': ids[back % 4],
      'title': t('مراجعة', 'Review'),
      'planned_on': dateKey(d(-back)),
      'start_min': 18 * 60,
      'planned_min': 60,
      'actual_min': back == 3 ? 0 : 40 + back * 5,
      'done': back != 3,
    });
  }
  await repo.save('study_sessions', {
    'course_id': st,
    'title': t('المتغيرات العشوائية', 'Random variables'),
    'planned_on': dateKey(d(1)),
    'start_min': 19 * 60,
    'planned_min': 50,
    'difficulty': 3,
  });
  await repo.save('events', {
    'title': t('ورشة سيرة ذاتية', 'CV workshop'),
    'kind': 'event',
    'starts_at': isoUtc(d(3, 14)),
    'ends_at': isoUtc(d(3, 15, 30)),
    'location': t('المكتبة', 'Library'),
  });
  await repo.save('resources', {
    'course_id': db,
    'title': t('مرجع PostgreSQL', 'PostgreSQL docs'),
    'category': 'book',
    'file_type': 'link',
    'url': 'https://www.postgresql.org/docs/',
  });
}

int _color(int i) => AppColors.courseColors[i % AppColors.courseColors.length].toARGB32();
