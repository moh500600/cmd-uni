import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/gpa.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../assignments/assignments_screen.dart';
import '../attendance/attendance_screen.dart';
import '../exams/exams_screen.dart';
import '../grades/grades_screen.dart';
import '../notes/notes_screen.dart';
import '../resources/resources_screen.dart';
import '../timetable/session_form_screen.dart';
import 'course_form_screen.dart';

class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final c = a?.course(courseId);
    if (a == null || c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.tr('not_found'))),
      );
    }
    final color = AppColors.course(c.color);
    final tabs = ['tab_overview', 'tab_schedule', 'nav_assignments', 'nav_exams', 'nav_grades', 'nav_attendance', 'nav_notes', 'tab_files'];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CourseDot(c, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l.tr('edit'),
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseFormScreen(courseId: c.id))),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                final repo = ref.read(repoProvider)!;
                if (v == 'archive') {
                  await repo.save('courses', {'id': c.id, 'archived': !c.archived}, log: c.name);
                } else if (v == 'delete' && await confirm(context, l.tr('delete_course_confirm'))) {
                  await repo.delete('courses', c.id, log: c.name);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'archive', child: Text(l.tr(c.archived ? 'unarchive' : 'archive'))),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: color,
            tabs: [for (final t in tabs) Tab(text: l.tr(t))],
          ),
        ),
        body: TabBarView(
          children: [
            _Overview(c, a),
            _Schedule(c, a),
            AssignmentList(courseId: c.id),
            ExamList(courseId: c.id),
            CourseGradeBook(courseId: c.id),
            CourseAttendancePanel(courseId: c.id),
            NotesList(courseId: c.id),
            ResourceList(courseId: c.id),
          ],
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  final Course c;
  final Academic a;
  const _Overview(this.c, this.a);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final pct = a.percentOf(c);
    final g = a.gradedOf(c);
    final att = a.attendanceOf(c);
    final units = a.units.where((u) => u.courseId == c.id).toList()..sort((x, y) => x.position.compareTo(y.position));
    final term = a.terms.where((t) => t.id == c.termId).firstOrNull;
    return PageList(
      children: [
        StatGrid(
          children: [
            StatTile(icon: Icons.grade_rounded, label: l.tr('course_total'), value: pct == null ? '—' : '${roundTo(pct)}%', color: AppColors.primary),
            StatTile(icon: Icons.workspace_premium_rounded, label: l.tr('grade'), value: g?.band.letter ?? '—', color: AppColors.accent),
            StatTile(
              icon: Icons.fact_check_rounded,
              label: l.tr('attendance_rate'),
              value: att.attendanceRate == null ? '—' : l.pct(att.attendanceRate!),
              color: AppColors.success,
            ),
            StatTile(
              icon: Icons.person_off_rounded,
              label: l.tr('absences_left'),
              value: att.remainingAllowed?.toString() ?? '—',
              color: (att.remainingAllowed ?? 9) <= 1 ? AppColors.danger : AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(context, Icons.tag_rounded, l.tr('course_code'), c.code),
                _row(context, Icons.person_rounded, l.tr('instructor'), c.instructor),
                _row(context, Icons.account_balance_rounded, l.tr('department'), c.department),
                _row(context, Icons.timelapse_rounded, l.tr('credit_hours'), c.creditHours.toString()),
                _row(context, Icons.date_range_rounded, l.tr('term'), term?.name ?? ''),
                if (c.description.isNotEmpty) ...[const Divider(height: 20), Text(c.description)],
              ],
            ),
          ),
        ),
        if (c.referencesText.isNotEmpty) ...[
          SectionTitle(l.tr('references_books'), icon: Icons.library_books_rounded),
          Card(
            child: Padding(padding: const EdgeInsets.all(14), child: Text(c.referencesText)),
          ),
        ],
        if (lines(c.links).isNotEmpty) ...[
          SectionTitle(l.tr('lecture_links'), icon: Icons.link_rounded),
          Card(
            child: Column(
              children: [
                for (final u in lines(c.links))
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr),
                    onTap: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
          ),
        ],
        SectionTitle(
          l.tr('course_units'),
          icon: Icons.view_list_rounded,
          trailing: IconButton(tooltip: l.tr('add_unit'), icon: const Icon(Icons.add_circle_outline_rounded), onPressed: () => _editUnit(context, ref, null)),
        ),
        if (units.isEmpty) Text(l.tr('units_hint'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        for (final u in units)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: CheckboxListTile(
              value: u.done,
              onChanged: (v) => ref.read(repoProvider)!.save('course_units', {'id': u.id, 'done': v ?? false}),
              title: Text(u.title),
              subtitle: Text('${l.tr('difficulty')}: ${l.tr('diff_${u.difficulty}')}'),
              secondary: IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _editUnit(context, ref, u)),
            ),
          ),
      ],
    );
  }

  Future<void> _editUnit(BuildContext context, WidgetRef ref, CourseUnit? u) async {
    final l = context.l;
    final t = TextEditingController(text: u?.title ?? '');
    var diff = u?.difficulty ?? 2;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(l.tr(u == null ? 'add_unit' : 'edit_unit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: t,
                autofocus: true,
                decoration: InputDecoration(labelText: l.tr('unit_title')),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  for (final d in [1, 2, 3]) ButtonSegment(value: d, label: Text(l.tr('diff_$d'))),
                ],
                selected: {diff},
                onSelectionChanged: (s) => set(() => diff = s.first),
              ),
            ],
          ),
          actions: [
            if (u != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(l.tr('save'))),
          ],
        ),
      ),
    );
    final repo = ref.read(repoProvider)!;
    if (r == 'delete' && u != null) await repo.delete('course_units', u.id);
    if (r == 'save' && t.text.trim().isNotEmpty) {
      final count = a.units.where((x) => x.courseId == c.id).length;
      await repo.save('course_units', {'id': u?.id, 'course_id': c.id, 'title': t.text.trim(), 'difficulty': diff, if (u == null) 'position': count});
    }
  }

  Widget _row(BuildContext context, IconData i, String k, String v) => v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(i, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('$k: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Expanded(
                child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
}

class _Schedule extends StatelessWidget {
  final Course c;
  final Academic a;
  const _Schedule(this.c, this.a);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ss = a.sessions.where((s) => s.courseId == c.id).toList();
    return PageList(
      children: [
        for (final s in ss)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(s.online ? Icons.videocam_rounded : Icons.meeting_room_rounded, color: AppColors.course(c.color)),
              title: Text('${l.weekdayName(s.weekday)}  ${hhmm(s.startMin)} – ${hhmm(s.endMin)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([l.tr('sk_${s.kind}'), if (s.room.isNotEmpty) s.room, if (s.instructor.isNotEmpty) s.instructor].join(' · ')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionFormScreen(sessionId: s.id))),
            ),
          ),
        if (ss.isEmpty) EmptyState(icon: Icons.view_week_rounded, title: l.tr('no_sessions')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionFormScreen(courseId: c.id))),
          icon: const Icon(Icons.add_rounded),
          label: Text(l.tr('add_session')),
        ),
      ],
    );
  }
}
