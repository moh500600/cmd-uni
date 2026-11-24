import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/attendance.dart';
import '../../../domain/services/gpa.dart';

import 'package:decimal/decimal.dart';

import '../../providers/providers.dart';
import '../../widgets/agenda_tile.dart';
import '../../widgets/common.dart';
import '../assignments/assignment_detail_screen.dart';
import '../assignments/assignment_form_screen.dart';
import '../courses/course_form_screen.dart';
import '../exams/exam_detail_screen.dart';
import '../settings/demo_data.dart';
import '../shell/home_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final async = ref.watch(academicProvider);
    final a = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(a == null || a.profile.fullName.isEmpty ? l.tr('app_name') : l.tr('hello_name', {'name': a.profile.fullName.split(' ').first})),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dash_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignmentFormScreen())),
        tooltip: l.tr('add_assignment'),
        child: const Icon(Icons.add_rounded),
      ),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : PageList(onRefresh: () async => ref.read(revisionProvider.notifier).bump(), children: _body(context, ref, a)),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref, Academic a) {
    final l = context.l;
    final now = DateTime.now();
    if (a.courses.isEmpty) {
      return [
        Card(
          child: EmptyState(
            icon: Icons.school_rounded,
            title: l.tr('welcome_title'),
            subtitle: l.tr('welcome_sub'),
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('first_course'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseFormScreen())),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.tr('add_first_course')),
                ),
                OutlinedButton.icon(
                  onPressed: () => openSection(context, 'nav_profile'),
                  icon: const Icon(Icons.badge_rounded),
                  label: Text(l.tr('setup_profile')),
                ),
                TextButton.icon(
                  key: const Key('demo_data'),
                  onPressed: () async {
                    final repo = ref.read(repoProvider);
                    if (repo != null) await loadDemoData(repo, l.ar);
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: Text(l.tr('load_demo')),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final today = a.agendaOn(now);
    final lecturesToday = today.where((i) => i.kind == 'lecture').length;
    final open = a.openAssignments(now);
    final overdue = a.overdue(now);
    final exams = a.upcomingExams(now);
    final term = a.currentTerm;
    final termGpa = a.termGpa(term?.id).gpa;
    final cum = a.cumulative.gpa;
    final completion = a.termCompletion;
    String gpa(Decimal? d) => d == null ? '—' : roundTo(d).toString();
    final urgent = [...overdue, ...a.dueWithin(now, const Duration(hours: 72)).where((x) => !overdue.contains(x))];
    final risky = a.currentCourses.where((c) {
      final r = a.attendanceOf(c).risk;
      return r == AbsenceRisk.warning || r == AbsenceRisk.exceeded;
    }).toList();
    final conflicts = a.timetableConflicts;
    final w = a.weekly(now);
    return [
      if (term != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          child: Text('${l.tr('current_term')}: ${term.name}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      StatGrid(
        children: [
          StatTile(
            icon: Icons.menu_book_rounded,
            label: l.tr('stat_courses'),
            value: '${a.currentCourses.length}',
            color: AppColors.primaryLight,
            onTap: () => openSection(context, 'nav_courses'),
          ),
          StatTile(
            icon: Icons.co_present_rounded,
            label: l.tr('stat_lectures_today'),
            value: '$lecturesToday',
            color: AppColors.info,
            onTap: () => openSection(context, 'nav_timetable'),
          ),
          StatTile(
            icon: Icons.assignment_rounded,
            label: l.tr('stat_due'),
            value: '${open.length - overdue.length}',
            color: AppColors.accent,
            onTap: () => openSection(context, 'nav_assignments'),
          ),
          StatTile(
            icon: Icons.assignment_late_rounded,
            label: l.tr('stat_overdue'),
            value: '${overdue.length}',
            color: AppColors.danger,
            onTap: () => openSection(context, 'nav_assignments'),
          ),
          StatTile(
            icon: Icons.quiz_rounded,
            label: l.tr('stat_exams'),
            value: '${exams.length}',
            color: AppColors.purple,
            onTap: () => openSection(context, 'nav_exams'),
          ),
          StatTile(
            icon: Icons.account_tree_rounded,
            label: l.tr('stat_projects'),
            value: '${a.activeProjects.length}',
            color: const Color(0xFF0D9488),
            onTap: () => openSection(context, 'nav_projects'),
          ),
          StatTile(
            icon: Icons.task_alt_rounded,
            label: l.tr('stat_completion'),
            value: completion == null ? '—' : l.pct(completion * 100),
            color: AppColors.success,
          ),
          StatTile(
            icon: Icons.trending_up_rounded,
            label: l.tr('term_gpa'),
            value: gpa(termGpa),
            color: AppColors.primary,
            onTap: () => openSection(context, 'nav_grades'),
          ),
          StatTile(
            icon: Icons.workspace_premium_rounded,
            label: l.tr('cumulative_gpa'),
            value: gpa(cum),
            color: const Color(0xFFB45309),
            onTap: () => openSection(context, 'nav_grades'),
          ),
          StatTile(
            icon: Icons.hourglass_bottom_rounded,
            label: l.tr('completed_hours'),
            value: l.numText(a.completedHours.toDouble()),
            color: const Color(0xFF475569),
          ),
        ],
      ),
      if (conflicts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              title: Text(l.tr('conflicts_found', {'n': '${conflicts.length}'})),
              subtitle: Text(conflicts.map((p) => '${a.course(p.$1.courseId)?.name} ↔ ${a.course(p.$2.courseId)?.name}').join('\n')),
              onTap: () => openSection(context, 'nav_timetable'),
            ),
          ),
        ),
      for (final c in risky)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            color: AppColors.warning.withValues(alpha: 0.10),
            child: ListTile(
              leading: const Icon(Icons.person_off_rounded, color: AppColors.warning),
              title: Text(l.tr('absence_alert', {'course': c.name})),
              subtitle: Text(_absenceText(l, a.attendanceOf(c))),
              onTap: () => openSection(context, 'nav_attendance'),
            ),
          ),
        ),
      SectionTitle(l.tr('today_schedule'), icon: Icons.today_rounded, trailing: Text(l.weekday(now))),
      if (today.isEmpty)
        Card(
          child: EmptyState(icon: Icons.free_breakfast_rounded, title: l.tr('nothing_today')),
        ),
      for (final it in today) AgendaTile(it, a),
      SectionTitle(l.tr('urgent_tasks'), icon: Icons.priority_high_rounded),
      if (urgent.isEmpty)
        Card(
          child: EmptyState(icon: Icons.check_circle_outline_rounded, title: l.tr('no_urgent')),
        ),
      for (final x in urgent.take(6))
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CourseDot(a.course(x.courseId), size: 14),
            title: Text(x.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${courseName(context, a.course(x.courseId))} · ${x.dueAt == null ? '' : l.dateTime(x.dueAt!)}'),
            trailing: Pill(l.tr('st_${effectiveStatus(x, now)}'), AppColors.status(effectiveStatus(x, now))),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: x.id))),
          ),
        ),
      SectionTitle(l.tr('upcoming_exams'), icon: Icons.quiz_rounded),
      if (exams.isEmpty)
        Card(
          child: EmptyState(icon: Icons.event_available_rounded, title: l.tr('no_exams')),
        ),
      for (final e in exams.take(4))
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _CountBox(Countdown.between(now, e.startsAt!).days),
            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${courseName(context, a.course(e.courseId))} · ${l.dateTime(e.startsAt!)}'),
            trailing: e.topics.isEmpty
                ? null
                : Ring(value: ExamPrep.of(e, now).readiness, label: l.pct(ExamPrep.of(e, now).readiness * 100), color: AppColors.purple, size: 44),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: e.id))),
          ),
        ),
      SectionTitle(l.tr('weekly_summary'), icon: Icons.insights_rounded),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _kv(context, l.tr('ws_done'), '${w.assignmentsDone}'),
              _kv(context, l.tr('ws_due'), '${w.assignmentsDue}'),
              _kv(context, l.tr('ws_exams'), '${w.examsThisWeek}'),
              _kv(context, l.tr('ws_study'), l.minutes(w.studyMinutes)),
              _kv(context, l.tr('ws_attendance'), w.attendanceRate == null ? '—' : l.pct(w.attendanceRate! * 100)),
              _kv(context, l.tr('ws_overdue'), '${w.overdue}'),
            ],
          ),
        ),
      ),
    ];
  }

  static String _absenceText(L10n l, AttendanceStats s) => s.risk == AbsenceRisk.exceeded
      ? l.tr('absence_exceeded', {'n': '${s.effectiveAbsences}', 'max': '${s.maxAllowed}'})
      : l.tr('absence_left', {'n': '${s.remainingAllowed}'});

  static Widget _kv(BuildContext context, String k, String v) => SizedBox(
    width: 140,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(k, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    ),
  );
}

class _CountBox extends StatelessWidget {
  final int days;
  const _CountBox(this.days);
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$days',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.purple),
        ),
        Text(context.tr('days_short'), style: const TextStyle(fontSize: 10, color: AppColors.purple)),
      ],
    ),
  );
}
