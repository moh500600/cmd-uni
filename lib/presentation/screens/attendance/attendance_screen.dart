import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/academic.dart';
import '../../../domain/services/attendance.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

Color statusColor(String s) => switch (s) {
  'present' => AppColors.success,
  'absent' => AppColors.danger,
  'late' => AppColors.warning,
  _ => AppColors.info,
};

IconData statusIcon(String s) => switch (s) {
  'present' => Icons.check_circle_rounded,
  'absent' => Icons.cancel_rounded,
  'late' => Icons.schedule_rounded,
  _ => Icons.verified_user_rounded,
};

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tr('nav_attendance'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final now = DateTime.now();
    final todaySessions = a.agendaOn(now).where((i) => i.kind == 'lecture').toList();
    final repo = ref.read(repoProvider)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('nav_attendance'))),
      body: PageList(
        children: [
          SectionTitle(l.tr('roll_call_today'), icon: Icons.how_to_reg_rounded),
          if (todaySessions.isEmpty) Text(l.tr('no_lectures_today_att'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final it in todaySessions)
            () {
              final rec = a.attendance.where((r) => r.courseId == it.courseId && r.sessionId == it.refId && dateKey(r.onDate) == dateKey(now)).firstOrNull;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${it.title} · ${l.time(it.start)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final s in kAttendanceStatuses)
                            ChoiceChip(
                              avatar: Icon(statusIcon(s), size: 16, color: statusColor(s)),
                              label: Text(l.tr('att_$s')),
                              selected: rec?.status == s,
                              onSelected: (_) => repo.markAttendance(it.courseId!, now, s, sessionId: it.refId),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }(),
          SectionTitle(l.tr('by_course'), icon: Icons.menu_book_rounded),
          if (a.currentCourses.isEmpty) EmptyState(icon: Icons.menu_book_rounded, title: l.tr('no_courses')),
          for (final c in a.currentCourses) _CourseCard(c, a),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course c;
  final Academic a;
  const _CourseCard(this.c, this.a);
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final s = a.attendanceOf(c);
    final color = switch (s.risk) {
      AbsenceRisk.exceeded => AppColors.danger,
      AbsenceRisk.warning => AppColors.warning,
      _ => AppColors.success,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(c.name)),
              body: CourseAttendancePanel(courseId: c.id),
            ),
          ),
        ),
        leading: Ring(value: (s.attendanceRate ?? 0) / 100, label: s.attendanceRate == null ? '—' : '${s.attendanceRate!.round()}%', color: color, size: 48),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(_line(l, s)),
        trailing: s.risk == AbsenceRisk.exceeded || s.risk == AbsenceRisk.warning ? Icon(Icons.warning_amber_rounded, color: color) : null,
      ),
    );
  }

  static String _line(L10n l, AttendanceStats s) {
    final parts = [
      l.tr('att_counts', {'p': '${s.present}', 'a': '${s.absent}', 'l': '${s.late}'}),
      if (s.maxAllowed != null) l.tr('absences_used', {'n': '${s.effectiveAbsences}', 'max': '${s.maxAllowed}'}),
      if (s.maxAllowed == null) l.tr('set_total_lectures'),
    ];
    return parts.join(' · ');
  }
}

/// One course's attendance: the limit math, a manual entry form, and the log.
class CourseAttendancePanel extends ConsumerStatefulWidget {
  final String courseId;
  const CourseAttendancePanel({super.key, required this.courseId});
  @override
  ConsumerState<CourseAttendancePanel> createState() => _CourseAttendancePanelState();
}

class _CourseAttendancePanelState extends ConsumerState<CourseAttendancePanel> {
  DateTime day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = ref.watch(academicProvider).value;
    final c = a?.course(widget.courseId);
    if (a == null || c == null) return const SizedBox.shrink();
    final s = a.attendanceOf(c);
    final recs = a.attendance.where((r) => r.courseId == c.id).toList();
    final repo = ref.read(repoProvider)!;
    return PageList(
      children: [
        StatGrid(
          children: [
            StatTile(
              icon: Icons.percent_rounded,
              label: l.tr('attendance_rate'),
              value: s.attendanceRate == null ? '—' : l.pct(s.attendanceRate!),
              color: AppColors.success,
            ),
            StatTile(icon: Icons.person_off_rounded, label: l.tr('effective_absences'), value: '${s.effectiveAbsences}', color: AppColors.danger),
            StatTile(icon: Icons.shield_rounded, label: l.tr('max_absences'), value: s.maxAllowed?.toString() ?? '—', color: AppColors.info),
            StatTile(
              icon: Icons.event_available_rounded,
              label: l.tr('absences_left'),
              value: s.remainingAllowed?.toString() ?? '—',
              color: (s.remainingAllowed ?? 9) <= 1 ? AppColors.danger : AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: (s.risk == AbsenceRisk.exceeded ? AppColors.danger : (s.risk == AbsenceRisk.warning ? AppColors.warning : AppColors.success)).withValues(
            alpha: 0.08,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(switch (s.risk) {
              AbsenceRisk.exceeded => l.tr('risk_exceeded', {'n': '${s.effectiveAbsences}', 'max': '${s.maxAllowed}'}),
              AbsenceRisk.warning => l.tr('risk_warning', {'n': '${s.remainingAllowed}'}),
              AbsenceRisk.safe => l.tr('risk_safe', {'n': '${s.remainingAllowed}'}),
              AbsenceRisk.unknown => l.tr('risk_unknown'),
            }, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l.tr('att_rules_line', {
              'pct': c.absenceLimitPct?.toString() ?? a.profile.absenceLimitPct.toString(),
              'late': '${a.profile.latePerAbsence}',
              'total': s.totalLectures == 0 ? '—' : '${s.totalLectures}',
            }),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        SectionTitle(l.tr('record_attendance'), icon: Icons.edit_calendar_rounded),
        DateTimeField(label: l.tr('date'), value: day, clearable: false, onChanged: (v) => setState(() => day = v ?? day)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final st in kAttendanceStatuses)
              FilledButton.tonalIcon(
                key: Key('mark_$st'),
                icon: Icon(statusIcon(st), color: statusColor(st)),
                label: Text(l.tr('att_$st')),
                onPressed: () async {
                  await repo.markAttendance(c.id, day, st);
                  if (context.mounted) toast(context, l.tr('attendance_saved'));
                },
              ),
          ],
        ),
        SectionTitle(l.tr('attendance_log'), icon: Icons.history_rounded),
        if (recs.isEmpty) Text(l.tr('no_records')),
        for (final r in recs)
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Icon(statusIcon(r.status), color: statusColor(r.status)),
              title: Text('${l.weekday(r.onDate)} ${l.date(r.onDate)}'),
              subtitle: r.note.isEmpty ? null : Text(r.note),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'delete' ? repo.delete('attendance', r.id) : repo.save('attendance', {'id': r.id, 'status': v}),
                itemBuilder: (_) => [
                  for (final st in kAttendanceStatuses) PopupMenuItem(value: st, child: Text(l.tr('att_$st'))),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l.tr('delete'), style: const TextStyle(color: AppColors.danger)),
                  ),
                ],
                child: Pill(l.tr('att_${r.status}'), statusColor(r.status)),
              ),
            ),
          ),
      ],
    );
  }
}
