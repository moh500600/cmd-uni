// UI smoke test: boots the real app on an in-memory database as an offline
// student, loads the demo term through the real repository, and renders every
// screen in Arabic and English (phone, desktop side rail, dark theme). Any
// Flutter error (overflow, exception) or a missing translation fails it.
// With SCREENSHOTS=1 it writes PNGs to build/screens/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uni_planner/app.dart';
import 'package:uni_planner/core/l10n/l10n.dart';
import 'package:uni_planner/data/db/app_database.dart';
import 'package:uni_planner/presentation/providers/providers.dart';
import 'package:uni_planner/presentation/screens/assignments/assignment_detail_screen.dart';
import 'package:uni_planner/presentation/screens/share/share_screen.dart';
import 'package:uni_planner/presentation/screens/assignments/assignment_form_screen.dart';

import 'package:uni_planner/presentation/screens/attendance/attendance_screen.dart';
import 'package:uni_planner/presentation/screens/calendar/event_form_screen.dart';
import 'package:uni_planner/presentation/screens/courses/course_detail_screen.dart';
import 'package:uni_planner/presentation/screens/courses/course_form_screen.dart';
import 'package:uni_planner/presentation/screens/exams/exam_detail_screen.dart';
import 'package:uni_planner/presentation/screens/exams/exam_form_screen.dart';
import 'package:uni_planner/presentation/screens/grades/gpa_settings_screen.dart';
import 'package:uni_planner/presentation/screens/grades/grades_screen.dart';
import 'package:uni_planner/presentation/screens/notes/note_editor_screen.dart';
import 'package:uni_planner/presentation/screens/projects/project_detail_screen.dart';
import 'package:uni_planner/presentation/screens/settings/demo_data.dart';
import 'package:uni_planner/presentation/screens/settings/settings_screen.dart';
import 'package:uni_planner/presentation/screens/settings/terms_screen.dart';
import 'package:uni_planner/presentation/screens/shell/home_shell.dart';
import 'package:uni_planner/presentation/screens/timetable/session_form_screen.dart';

final shots = Platform.environment['SCREENSHOTS'] == '1';
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final tajawal = FontLoader('Tajawal');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    final f = File('assets/fonts/Tajawal-$w.ttf');
    if (f.existsSync()) tajawal.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await tajawal.load();
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

final _errs = <String>[];
void Function(FlutterErrorDetails)? _origOnError;

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 600));
  if (_errs.isNotEmpty) {
    final all = _errs.join('\n----\n');
    _errs.clear();
    FlutterError.onError = _origOnError;
    fail('UI errors on/before $name:\n$all');
  }
  if (!shots) return;
  await tester.runAsync(() async {
    final b = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2.5);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/screens/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  sqfliteFfiInit();
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    await _loadFonts();
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('every screen renders with real data ($lang)', (tester) async {
      if (shots) debugDisableShadows = false;
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.7;
      addTearDown(tester.view.reset);
      final ar = lang == 'ar';
      _origOnError = FlutterError.onError;
      FlutterError.onError = (d) => _errs.add(d.toString());
      L10n.missing.clear();

      SharedPreferences.setMockInitialValues({'lang': lang, 'theme': ThemeMode.light.index});
      final prefs = await SharedPreferences.getInstance();
      late Database db;
      await tester.runAsync(() async {
        db = await AppDatabase.open(databaseFactoryFfiNoIsolate, 'file:smoke_$lang?mode=memory&cache=shared');
      });
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db), prefsProvider.overrideWithValue(prefs)]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: _boundary, child: const UniPlannerApp()),
        ),
      );
      await tester.pump();
      await _shot(tester, '${lang}_00_start');

      Future<void> settle([int n = 8]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 120));
        }
      }

      // empty state first (a brand-new student), then the demo term
      await settle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await _shot(tester, '${lang}_01_empty_dashboard');
      await tester.runAsync(() => loadDemoData(container.read(repoProvider)!, ar));
      await settle(10);
      await _shot(tester, '${lang}_02_dashboard');

      final a = await tester.runAsync(() => container.read(academicProvider.future));
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      var n = 3;
      Future<void> open(Widget w, String name, {Future<void> Function()? act}) async {
        nav.push(MaterialPageRoute(builder: (_) => w));
        await settle();
        if (act != null) await act();
        await _shot(tester, '${lang}_${(n++).toString().padLeft(2, '0')}_$name');
        expect(tester.takeException(), isNull, reason: name);
        nav.pop();
        await settle(3);
      }

      for (final s in kSections.skip(1)) {
        await open(s.build(), s.key.replaceFirst('nav_', ''));
      }
      final course = a!.currentCourses.firstWhere((c) => a.gradesOf(c.id).length > 1);
      final asg = a.assignments.firstWhere((x) => a.subtasksOf(x.id).isNotEmpty);
      final exam = a.exams.firstWhere((e) => e.kind == 'midterm');
      await open(CourseDetailScreen(courseId: course.id), 'course_detail');
      await open(AssignmentDetailScreen(assignmentId: asg.id), 'assignment_detail');
      await open(ExamDetailScreen(examId: exam.id), 'exam_detail');
      await open(ProjectDetailScreen(projectId: a.projects.first.id), 'project_detail');
      await open(
        Scaffold(
          appBar: AppBar(),
          body: CourseGradeBook(courseId: course.id),
        ),
        'gradebook',
      );
      await open(
        Scaffold(
          appBar: AppBar(),
          body: CourseAttendancePanel(courseId: course.id),
        ),
        'attendance_course',
      );
      await open(NoteEditorScreen(noteId: a.notes.first.id), 'note_editor');
      await open(const CourseFormScreen(), 'course_form');
      await open(SessionFormScreen(courseId: course.id), 'session_form');
      await open(const AssignmentFormScreen(), 'assignment_form');
      await open(const ExamFormScreen(), 'exam_form');
      await open(const EventFormScreen(), 'event_form');
      await open(const GpaSettingsScreen(), 'gpa_settings');
      await open(const TermsScreen(), 'terms');
      await open(const NotificationSettingsScreen(), 'notifications');
      await open(const AttendanceRulesScreen(), 'attendance_rules');
      await open(const ShareScreen(), 'share');

      // a real flow: mark an attendance through the UI and see the log grow
      final before = a.attendance.where((r) => r.courseId == course.id).length;
      nav.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(body: CourseAttendancePanel(courseId: course.id)),
        ),
      );
      await settle();
      await tester.tap(find.byKey(const Key('mark_late')));
      await settle();
      final after = (await tester.runAsync(() => container.read(academicProvider.future)))!.attendance.where((r) => r.courseId == course.id).length;
      expect(after, before + 1);
      nav.pop();
      await settle(3);

      // dark theme
      await tester.pump(const Duration(seconds: 5)); // let the snackbar go
      await tester.runAsync(() => container.read(settingsProvider.notifier).update(container.read(settingsProvider).copyWith(theme: ThemeMode.dark)));
      await settle();
      await _shot(tester, '${lang}_${n++}_dashboard_dark');
      await tester.runAsync(() => container.read(settingsProvider.notifier).update(container.read(settingsProvider).copyWith(theme: ThemeMode.light)));

      // desktop: side rail
      tester.view.physicalSize = const Size(1440 * 1.5, 900 * 1.5);
      tester.view.devicePixelRatio = 1.5;
      await settle();
      expect(find.byType(NavigationRail), findsOneWidget);
      await _shot(tester, '${lang}_${n++}_desktop_dashboard');
      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(L10n(lang).tr('nav_grades'))));
      await settle();
      await _shot(tester, '${lang}_${n++}_desktop_grades');
      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(L10n(lang).tr('nav_calendar'))));
      await settle();
      await _shot(tester, '${lang}_${n++}_desktop_calendar');

      expect(L10n.missing, isEmpty, reason: 'untranslated keys');
      expect(tester.takeException(), isNull);
      FlutterError.onError = _origOnError;
      await tester.pumpWidget(const SizedBox());
      container.dispose(); // cancels the sync timers
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() => db.close());
      debugDisableShadows = true;
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
